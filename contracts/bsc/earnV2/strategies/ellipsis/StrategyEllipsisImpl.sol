pragma solidity 0.6.12;

import "./StrategyEllipsisStorage.sol";
import "../../defi/ellipsis.sol";
import "../../defi/pancake.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyEllipsisImpl is StrategyEllipsisStorage {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    event Deposit(address wantAddress, uint256 amountReceived, uint256 amountDeposited);
    event Withdraw(address wantAddress, uint256 amountRequested, uint256 amountWithdrawn);
    event Buyback(address earnedAddress, uint256 earnedAmount, uint256 buybackAmount, address buybackTokenAddress, uint256 burnAmount, address buybackAddress);

    modifier onlyEOA() {
        require(tx.origin == msg.sender);
        _;
    }

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

        uint256 before = eps3ToWant();
        _deposit(_wantAmt);
        uint256 diff = eps3ToWant().sub(before);
        if (diff > _wantAmt) {
            diff = _wantAmt;
        }

        emit Deposit(wantAddress, _wantAmt, diff);

        return diff;
    }

    function _deposit(uint256 _wantAmt) internal {
        uint256[3] memory depositArr;
        depositArr[getTokenIndex(wantAddress)] = _wantAmt;
        require(isPoolSafe(), "StrategyEllipsis: pool unsafe");
        StableSwap(ellipsisSwapAddress).add_liquidity(depositArr, 0);
        LpTokenStaker(ellipsisStakeAddress).deposit(poolId, IERC20(eps3Address).balanceOf(address(this)));
        require(isPoolSafe(), "StrategyEllipsis: pool unsafe");
    }

    function _depositAdditional(uint256 amount1, uint256 amount2, uint256 amount3) internal {
        uint256[3] memory depositArr;
        depositArr[0] = amount1;
        depositArr[1] = amount2;
        depositArr[2] = amount3;
        StableSwap(ellipsisSwapAddress).add_liquidity(depositArr, 0);
        LpTokenStaker(ellipsisStakeAddress).deposit(poolId, IERC20(eps3Address).balanceOf(address(this)));
    }
    
    function withdraw(uint256 _wantAmt)
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        _wantAmt = _wantAmt.mul(
            withdrawFeeDenom.sub(withdrawFeeNumer)
        ).div(withdrawFeeDenom);

        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        _withdraw(_wantAmt);
        wantBal = IERC20(wantAddress).balanceOf(address(this)).sub(wantBal);
        IERC20(wantAddress).safeTransfer(owner(), wantBal);

        emit Withdraw(wantAddress, _wantAmt, wantBal);

        return wantBal;
    }

    function _withdraw(uint256 _wantAmt) internal {
        require(isPoolSafe(), "StrategyEllipsis: pool unsafe");
        _wantAmt = _wantAmt.mul(
            withdrawFeeDenom.sub(withdrawFeeNumer)
        ).div(withdrawFeeDenom);

        (uint256 curEps3Bal, )= LpTokenStaker(ellipsisStakeAddress).userInfo(poolId, address(this));
        
        uint256 eps3Amount = _wantAmt.mul(curEps3Bal).div(eps3ToWant());
        LpTokenStaker(ellipsisStakeAddress).withdraw(poolId, eps3Amount);
        StableSwap(ellipsisSwapAddress).remove_liquidity_one_coin(
            IERC20(eps3Address).balanceOf(address(this)),
            getTokenIndexInt(wantAddress),
            0
        );
        require(isPoolSafe(), "StrategyEllipsis: pool unsafe");
    }

    function earn() external whenNotPaused onlyEOA {
        uint256 earnedAmt;
        LpTokenStaker(ellipsisStakeAddress).withdraw(poolId, 0);
        FeeDistribution(ellipsisDistibAddress).exit();

        earnedAmt = IERC20(epsAddress).balanceOf(address(this));
        earnedAmt = buyBack(earnedAmt);

        if (epsAddress != wantAddress) {
            IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
                earnedAmt,
                0,
                EPSToWantPath,
                address(this),
                now.add(600)
            );
        }
        
        uint256 busdBal = IERC20(busdAddress).balanceOf(address(this));
        uint256 usdcBal = IERC20(usdcAddress).balanceOf(address(this));
        uint256 usdtBal = IERC20(usdtAddress).balanceOf(address(this));
        if (busdBal.add(usdcBal).add(usdtBal) != 0) {
            _depositAdditional(
                busdBal,
                usdcBal,
                usdtBal
            );
        }

        lastEarnBlock = block.number;
    }

    function buyBack(uint256 _earnedAmt) internal returns (uint256) {
        if (buyBackRate <= 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

        IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
            buyBackAmt,
            0,
            EPSToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);
        emit Buyback(epsAddress, _earnedAmt, buyBackAmt, BELTAddress, burnAmt, buyBackAddress);

        return _earnedAmt.sub(buyBackAmt);
    }

    function _pause() override internal {
        super._pause();
        IERC20(epsAddress).safeApprove(pancakeRouterAddress, uint256(0));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(0));
        IERC20(busdAddress).safeApprove(ellipsisSwapAddress, uint256(0));
        IERC20(usdcAddress).safeApprove(ellipsisSwapAddress, uint256(0));
        IERC20(usdtAddress).safeApprove(ellipsisSwapAddress, uint256(0));
        IERC20(eps3Address).safeApprove(ellipsisStakeAddress, uint256(0));
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function _unpause() override internal {
        super._unpause();
        IERC20(epsAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(busdAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdcAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdtAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(eps3Address).safeApprove(ellipsisStakeAddress, uint256(-1));
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();
    }

    
    function getTokenIndex(address tokenAddr) internal pure returns (uint256) {
        if (tokenAddr == busdAddress) {
            return 0;
        } else if (tokenAddr == usdcAddress) {
            return 1;
        } else {
            return 2;
        }
    }

    function getTokenIndexInt(address tokenAddr) internal pure returns (int128) {
        if (tokenAddr == busdAddress) {
            return 0;
        } else if (tokenAddr == usdcAddress) {
            return 1;
        } else {
            return 2;
        }
    }

    function eps3ToWant() public view returns (uint256) {
        require(isPoolSafe(), "StrategyEllipsis: pool unsafe");
        (uint256 curEps3Bal, )= LpTokenStaker(ellipsisStakeAddress).userInfo(poolId, address(this));
        return curEps3Bal.mul(StableSwap(ellipsisSwapAddress).get_virtual_price()).div(1e18);
    }

    function isPoolSafe() public view returns (bool) {
        // CHANGES: get balances of token in stableswap except admin_fee
        uint256 busdBal = StableSwap(ellipsisSwapAddress).balances(getTokenIndex(busdAddress));
        uint256 usdcBal = StableSwap(ellipsisSwapAddress).balances(getTokenIndex(usdcAddress));
        uint256 usdtBal = StableSwap(ellipsisSwapAddress).balances(getTokenIndex(usdtAddress)); 
        uint256 most = busdBal > usdcBal ?
                (busdBal > usdtBal ? busdBal : usdtBal) : 
                (usdcBal > usdtBal ? usdcBal : usdtBal);
        uint256 least = busdBal < usdcBal ?
                (busdBal < usdtBal ? busdBal : usdtBal) : 
                (usdcBal < usdtBal ? usdcBal : usdtBal);

        return most <= least.mul(safetyCoeffNumer).div(safetyCoeffDenom);
    }

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere().add(
            eps3ToWant()
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

    function setSafetyCoeff(uint256 _safetyNumer, uint256 _safetyDenom) public {
        require(msg.sender == govAddress, "Not authorised");
        require(_safetyDenom != 0);
        require(_safetyNumer >= _safetyDenom);
        safetyCoeffNumer = _safetyNumer;
        safetyCoeffDenom = _safetyDenom;
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
        require(_token != epsAddress, "!safe");
        require(_token != eps3Address, "!safe");
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

    function setEPSToWantPath(address[] memory newPath) public {
        require(msg.sender == govAddress, "Not authorised");
        EPSToWantPath = newPath;
    }

    function updateStrategy() public {
    }

    receive() external payable {}
}
