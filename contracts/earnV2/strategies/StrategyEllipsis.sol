// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Strategy.sol";
import "../defi/ellipsis.sol";
import "../defi/pancake.sol";



contract StrategyEllipsis is Strategy {

    address public wantAddress;
    address public pancakeRouterAddress;
    
    // BUSD
    address public constant busdAddress = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    // USDC
    address public constant usdcAddress = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    // USDT
    address public constant usdtAddress = 0x55d398326f99059fF775485246999027B3197955;

    // BUSD <-> USDC <-> USDT
    address public constant eps3Address = 0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452;

    // EPS
    address public constant epsAddress =
    0xA7f552078dcC247C2684336020c03648500C6d9F;

    address public constant ellipsisSwapAddress =
    0x160CAed03795365F3A589f10C379FfA7d75d4E76;
    
    address public constant ellipsisStakeAddress =
    0xcce949De564fE60e7f96C85e55177F8B9E4CF61b;
    
    address public constant ellipsisDistibAddress =
    0x4076CC26EFeE47825917D0feC3A79d0bB9a6bB5c;

    uint256 public immutable poolId;

    uint256 public safetyCoeffNumer = 10;
    uint256 public safetyCoeffDenom = 1;

    address public BELTAddress;

    address[] public EPSToWantPath;
    address[] public EPSToBELTPath;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _pancakeRouterAddress,
        uint256 _poolId,
        address[] memory _EPSToWantPath,
        address[] memory _EPSToBELTPath
    ) public {

        govAddress = msg.sender;
        BELTAddress = _BELTAddress;

        wantAddress = _wantAddress;

        poolId = _poolId;

        EPSToWantPath = _EPSToWantPath;
        EPSToBELTPath = _EPSToBELTPath;

        pancakeRouterAddress = _pancakeRouterAddress;

        withdrawFeeNumer = 1;
        withdrawFeeDenom = 1000;

        IERC20(epsAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(busdAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdcAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdtAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(eps3Address).safeApprove(ellipsisStakeAddress, uint256(-1));
    }
    
    function deposit(uint256 _wantAmt)
        override
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
        return diff;
    }

    function _deposit(uint256 _wantAmt) internal {
        uint256[3] memory depositArr;
        depositArr[getTokenIndex(wantAddress)] = _wantAmt;
        require(isPoolSafe(), 'pool unsafe');
        StableSwap(ellipsisSwapAddress).add_liquidity(depositArr, 0);
        LpTokenStaker(ellipsisStakeAddress).deposit(poolId, IERC20(eps3Address).balanceOf(address(this)));
        require(isPoolSafe(), 'pool unsafe');
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
        override
        public
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
        return wantBal;
    }

    function _withdraw(uint256 _wantAmt) internal {        
        // require(isPoolSafe(), 'pool unsafe');
        uint256 busdBal = IERC20(busdAddress).balanceOf(ellipsisSwapAddress);
        uint256 usdcBal = IERC20(usdcAddress).balanceOf(ellipsisSwapAddress);
        uint256 usdtBal = IERC20(usdtAddress).balanceOf(ellipsisSwapAddress);

        (uint256 curEps3Bal, )= LpTokenStaker(ellipsisStakeAddress).userInfo(poolId, address(this));
        uint256 totEps3Bal = IERC20(eps3Address).totalSupply();
        
        uint256[3] memory withdrawArr;
        withdrawArr[getTokenIndex(busdAddress)] = busdBal.mul(curEps3Bal).mul(_wantAmt).div(totEps3Bal).div(eps3ToWant());
        withdrawArr[getTokenIndex(usdcAddress)] = usdcBal.mul(curEps3Bal).mul(_wantAmt).div(totEps3Bal).div(eps3ToWant());
        withdrawArr[getTokenIndex(usdtAddress)] = usdtBal.mul(curEps3Bal).mul(_wantAmt).div(totEps3Bal).div(eps3ToWant());
        
        uint256 eps3Amount = StableSwap(ellipsisSwapAddress).calc_token_amount(withdrawArr, false);
        LpTokenStaker(ellipsisStakeAddress).withdraw(poolId, eps3Amount);
        StableSwap(ellipsisSwapAddress).remove_liquidity_one_coin(
            IERC20(eps3Address).balanceOf(address(this)),
            getTokenIndexInt(wantAddress),
            0
        );
        // require(isPoolSafe(), 'pool unsafe');
    }

    function earn() override external whenNotPaused {
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
        uint256 usdcBal = 0;/*IERC20(usdcAddress).balanceOf(address(this));*/
        uint256 usdtBal = 0;/*IERC20(usdtAddress).balanceOf(address(this));*/
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

        return _earnedAmt.sub(buyBackAmt);
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");

        _pause();

        IERC20(epsAddress).safeApprove(pancakeRouterAddress, uint256(0));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(0));
        IERC20(busdAddress).safeApprove(ellipsisSwapAddress, uint256(0));
        IERC20(usdcAddress).safeApprove(ellipsisSwapAddress, uint256(0));
        IERC20(usdtAddress).safeApprove(ellipsisSwapAddress, uint256(0));
        IERC20(eps3Address).safeApprove(ellipsisStakeAddress, uint256(0));
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();

        IERC20(epsAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(busdAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdcAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdtAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(eps3Address).safeApprove(ellipsisStakeAddress, uint256(-1));
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
        uint256 busdBal = IERC20(busdAddress).balanceOf(ellipsisSwapAddress);
        uint256 usdcBal = IERC20(usdcAddress).balanceOf(ellipsisSwapAddress);
        uint256 usdtBal = IERC20(usdtAddress).balanceOf(ellipsisSwapAddress);
        (uint256 curEps3Bal, )= LpTokenStaker(ellipsisStakeAddress).userInfo(poolId, address(this));
        uint256 totEps3Bal = IERC20(eps3Address).totalSupply();
        return busdBal.mul(curEps3Bal).div(totEps3Bal)
            .add(
                usdcBal.mul(curEps3Bal).div(totEps3Bal)
            )
            .add(
                usdtBal.mul(curEps3Bal).div(totEps3Bal)
            );
    }

    function isPoolSafe() public view returns (bool) {
        uint256 busdBal = IERC20(busdAddress).balanceOf(ellipsisSwapAddress);
        uint256 usdcBal = IERC20(usdcAddress).balanceOf(ellipsisSwapAddress);
        uint256 usdtBal = IERC20(usdtAddress).balanceOf(ellipsisSwapAddress);        
        uint256 most = busdBal > usdcBal ?
                (busdBal > usdtBal ? busdBal : usdtBal) : 
                (usdcBal > usdtBal ? usdcBal : usdtBal);
        uint256 least = busdBal < usdcBal ?
                (busdBal < usdtBal ? busdBal : usdtBal) : 
                (usdcBal < usdtBal ? usdcBal : usdtBal);
        return most <= least.mul(safetyCoeffNumer).div(safetyCoeffDenom);
    }

    function wantLockedTotal() override public view returns (uint256) {
        return wantLockedInHere().add(
            // balanceSnapshot
            eps3ToWant()
        );
    }

    function wantLockedInHere() override public view returns (uint256) {
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        return wantBal;
    }

    function setbuyBackRate(uint256 _buyBackRate) override public {
        require(msg.sender == govAddress, "Not authorised");
        require(buyBackRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
    }

    function setSafetyCoeff(uint256 _safetyNumer, uint256 _safetyDenom) public {
        require(msg.sender == govAddress, "Not authorised");
        require(_safetyDenom != 0);
        require(_safetyNumer >= _safetyDenom);
        safetyCoeffNumer = _safetyNumer;
        safetyCoeffDenom = _safetyDenom;
    }

    function setGov(address _govAddress) override public {
        require(msg.sender == govAddress, "Not authorised");
        govAddress = _govAddress;
    }
    
    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) override public {
        require(msg.sender == govAddress, "!gov");
        require(_token != epsAddress, "!safe");
        require(_token != eps3Address, "!safe");
        require(_token != wantAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }

    receive() external payable {}
}
