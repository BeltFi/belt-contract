pragma solidity 0.6.12;

import "./StrategyAutoStorage.sol";
import "../../defi/autoFarm.sol";
import "../../defi/pancake.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyAutoImpl is StrategyAutoStorage {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    function deposit(uint256 _wantAmt)
        public
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        uint256 before = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this));
        AUTOFarm(autoFarmAddress).deposit(poolId, _wantAmt);
        uint256 diff = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this)).sub(before);
        balanceSnapshot = balanceSnapshot.add(
            diff
        );
        return diff;
    }

    function earn() external whenNotPaused {
        AUTOFarm(autoFarmAddress).withdraw(poolId, 0);

        uint256 prevBalance = balanceSnapshot;
        uint256 currentBalance = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this));

        uint256 earnedAmt = IERC20(autoAddress).balanceOf(address(this));
        earnedAmt = buyBack(earnedAmt);

        if (autoAddress != wantAddress) {
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                earnedAmt,
                0,
                autoToWantPath,
                address(this),
                now.add(600)
            );
        }
        if (currentBalance > prevBalance) {
            earnedAmt = currentBalance.sub(prevBalance);
            buyBackWant(earnedAmt);
        }
        earnedAmt = IERC20(wantAddress).balanceOf(address(this));
        if (earnedAmt != 0) {
            AUTOFarm(autoFarmAddress).deposit(poolId, earnedAmt);
        }
        currentBalance = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this));
        balanceSnapshot = currentBalance > balanceSnapshot ? currentBalance : balanceSnapshot;
        lastEarnBlock = block.number;
    }

    function buyBackWant(uint256 _earnedAmt) internal {
        if (buyBackRate != 0) {
            uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);
            uint256 curWantBal = IERC20(wantAddress).balanceOf(address(this));
            if (curWantBal < buyBackAmt) {
                AUTOFarm(autoFarmAddress).withdraw(poolId, buyBackAmt.sub(curWantBal));
                buyBackAmt = IERC20(wantAddress).balanceOf(address(this));
            }
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                buyBackAmt,
                0,
                wantToBELTPath,
                address(this),
                now + 600
            );

            uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
            IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);        
        }
    }

    function buyBack(uint256 _earnedAmt) internal returns (uint256) {
        if (buyBackRate <= 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

        IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
            buyBackAmt,
            0,
            autoToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);

        return _earnedAmt.sub(buyBackAmt);
    }

    function withdraw(uint256 _wantAmt)
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        _wantAmt = _wantAmt.mul(withdrawFeeDenom.sub(withdrawFeeNumer)).div(withdrawFeeDenom);
        balanceSnapshot = balanceSnapshot.sub(
            _wantAmt
        );
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        AUTOFarm(autoFarmAddress).withdraw(poolId, _wantAmt);
        wantBal = IERC20(wantAddress).balanceOf(address(this)).sub(wantBal);
        IERC20(wantAddress).safeTransfer(owner(), wantBal);
        return wantBal;
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");

        _pause();

        IERC20(autoAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(autoFarmAddress, 0);
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();

        IERC20(autoAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(autoFarmAddress, uint256(-1));
    }

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere().add(
            balanceSnapshot
            // AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this))
        );
    }

    function wantLockedInHere() public view returns (uint256) {
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        return wantBal;
    }

    function setbuyBackRate(uint256 _buyBackRate) public {
        require(msg.sender == govAddress, "Not authorised");
        require(_buyBackRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
    }

    function setGov(address _govAddress) public {
        require(msg.sender == govAddress, "Not authorised");
        govAddress = _govAddress;
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != autoAddress, "!safe");
        require(_token != wantAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }

    function setWithdrawFee(uint256 _withdrawFeeNumer, uint256 _withdrawFeeDenom) external {
        require(msg.sender == govAddress, "Not authorised");
        require(_withdrawFeeDenom != 0, "denominator should not be 0");
        require(_withdrawFeeNumer.mul(10) <= _withdrawFeeDenom, "numerator value too big");
        withdrawFeeDenom = _withdrawFeeDenom;
        withdrawFeeNumer = _withdrawFeeNumer;
    }

    function getProxyAdmin() public view returns (address adm) {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            adm := sload(slot)
        }
    }

    function setPancakeRouterV2() public {
        require(msg.sender == govAddress, "!gov");
        uniRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }

    receive() external payable {}
}
