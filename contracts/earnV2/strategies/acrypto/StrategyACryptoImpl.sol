// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StrategyACryptoStorage.sol";
import "../../defi/acryptos.sol";
import "../../defi/pancake.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyACryptoImpl is StrategyACryptoStorage {
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

        uint before = _stakedWantTokens();
        _deposit(_wantAmt);
        uint diff = _stakedWantTokens().sub(before);

        balanceSnapshot = balanceSnapshot.add(diff);

        return diff;
    }

    function _deposit(uint256 _wantAmt) internal {
        ACryptoSVault(vaultAddress).deposit(_wantAmt);
        ACryptoSFarm(acsFarmAddress).deposit(vaultAddress, IERC20(vaultAddress).balanceOf(address(this)));
    }
    
    function withdraw(uint256 _wantAmt)
        public
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        _wantAmt = _wantAmt.mul(withdrawFeeDenom.sub(withdrawFeeNumer)).div(withdrawFeeDenom);
        balanceSnapshot = balanceSnapshot.sub(_wantAmt);
        
        if(_stakedWantTokens() < _wantAmt) {
            _wantAmt = _stakedWantTokens();
        }

        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        _withdraw(_wantAmt);        
        wantBal = IERC20(wantAddress).balanceOf(address(this)).sub(wantBal);
        IERC20(wantAddress).safeTransfer(owner(), wantBal);
        
        return wantBal;
    }

    function _withdraw(uint256 _wantAmt) internal {
        ACryptoSFarm(acsFarmAddress).withdraw(vaultAddress, _wantAmt.mul(1e18).div(ACryptoSVault(vaultAddress).getPricePerFullShare()));
        ACryptoSVault(vaultAddress).withdraw(IERC20(vaultAddress).balanceOf(address(this)));
    }

    function _stakedWantTokens() public view returns (uint256) {
        (uint256 _amount, , ,) = ACryptoSFarm(acsFarmAddress).userInfo(vaultAddress, address(this));
        return _amount.mul(ACryptoSVault(vaultAddress).getPricePerFullShare()).div(1e18);
    }

    function earn() external whenNotPaused {
        uint256 pending = ACryptoSFarm(acsFarmAddress).pendingSushi(vaultAddress, address(this));
        if(pending > harvestFee) {
            ACryptoSFarm(acsFarmAddress).harvest(vaultAddress);

            uint256 earnedAmt = ACSToken(acsAddress).balanceOf(address(this));
            earnedAmt = buyBack(earnedAmt);
            if (acsAddress != wantAddress) {
                IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
                    earnedAmt,
                    0,
                    ACSToWantPath,
                    address(this),
                    now.add(600)
                );
            }
        }

        uint256 prevBalance = balanceSnapshot;
        uint256 currentBalance = _stakedWantTokens();
        uint256 earnedWantAmt;

        if (prevBalance < currentBalance) {
            earnedWantAmt = currentBalance.sub(prevBalance);
            buyBackWant(earnedWantAmt);
        }
            
        earnedWantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (earnedWantAmt != 0) {
            _deposit(earnedWantAmt);
        }            
        balanceSnapshot = _stakedWantTokens();
        
        lastEarnBlock = block.number;
    }

    function buyBackWant(uint256 _earnedAmt) internal {
        if (buyBackRate != 0) {
            uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);
            uint256 curWantBal = IERC20(wantAddress).balanceOf(address(this));
            
            if(curWantBal < buyBackAmt) {
                _withdraw((buyBackAmt.sub(curWantBal)));
                buyBackAmt = IERC20(wantAddress).balanceOf(address(this));
            }

            IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
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

        IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
            buyBackAmt,
            0,
            ACSToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);

        return _earnedAmt.sub(buyBackAmt);
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");

        _pause();

        IERC20(acsAddress).safeApprove(pancakeRouterAddress, 0);
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, 0);
        IERC20(wantAddress).safeApprove(vaultAddress, 0);
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();

        IERC20(acsAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(vaultAddress, uint256(-1));
    }

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere().add(balanceSnapshot);
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
    
    function setHarvestFee(uint256 _harvestFee) public {
        require(msg.sender == govAddress, "Not authorised");
        harvestFee = _harvestFee;
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != acsAddress, "!safe");
        require(_token != wantAddress, "!safe");
        require(_token != vaultAddress, "!safe");

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

    receive() external payable {}
}
