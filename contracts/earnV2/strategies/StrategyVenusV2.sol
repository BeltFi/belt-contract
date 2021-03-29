pragma solidity 0.6.12;

import "./Strategy.sol";
import "../defi/venus.sol";
import "../defi/pancake.sol";


interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

contract StrategyVenusV2 is Strategy {
    bool public wantIsWBNB = false;
    address public wantAddress;
    address public vTokenAddress;
    address[] public venusMarkets;
    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant venusAddress =
    0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    address public constant earnedAddress = venusAddress;
    address public constant venusDistributionAddress =
    0xfD36E2c2a6789Db23113685031d7F16329158384;

    address public BELTAddress;

    uint256 public withdrawFeeRate = 1;
    uint256 public constant withdrawFeeRateMax = 10000;
    uint256 public constant withdrawFeeRateUL = 800;

    address[] public venusToWantPath;
    address[] public venusToBELTPath;
    address[] public wantToBELTPath;

    uint256 public borrowRate = 585;
    uint256 public borrowDepth = 3;
    uint256 public constant BORROW_RATE_MAX = 595;
    uint256 public constant BORROW_RATE_MAX_HARD = 599;
    uint256 public constant BORROW_DEPTH_MAX = 6;

    uint256 public supplyBal = 0;
    uint256 public borrowBal = 0;
    uint256 public supplyBalTargeted = 0;
    uint256 public supplyBalMin = 0;

	//only updated when deposit / withdraw / earn is called
	uint256 public balanceSnapshot;

    event StratRebalance(uint256 _borrowRate, uint256 _borrowDepth);

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _vTokenAddress,
        address _uniRouterAddress,

        address[] memory _venusToWantPath,
        address[] memory _venusToBELTPath,
        address[] memory _wantToBETLPATH
    ) public {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;
        wantAddress = _wantAddress;

        if (wantAddress == wbnbAddress) {
            wantIsWBNB = true;
        }

        venusToWantPath = _venusToWantPath;
        venusToBELTPath = _venusToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        vTokenAddress = _vTokenAddress;
        venusMarkets = [vTokenAddress];
        uniRouterAddress = _uniRouterAddress;

        IERC20(venusAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        if (!wantIsWBNB) {
            IERC20(wantAddress).safeApprove(vTokenAddress, uint256(-1));
        }

        IVenusDistribution(venusDistributionAddress).enterMarkets(venusMarkets);
    }

    function _supply(uint256 _amount) internal {
        if (wantIsWBNB) {
            IVBNB(vTokenAddress).mint{value: _amount}();
        } else {
            IVToken(vTokenAddress).mint(_amount);
        }
    }

    function _removeSupply(uint256 _amount) internal {
        IVToken(vTokenAddress).redeemUnderlying(_amount);
    }

    function _borrow(uint256 _amount) internal {
        IVToken(vTokenAddress).borrow(_amount);
    }

    function _repayBorrow(uint256 _amount) internal {
        if (wantIsWBNB) {
            IVBNB(vTokenAddress).repayBorrow{value: _amount}();
        } else {
            IVToken(vTokenAddress).repayBorrow(_amount);
        }
    }

    function deposit(uint256 _wantAmt)
        override
        public
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        updateBalance();

        uint prevBalance = wantLockedInHere().add(supplyBal).sub(borrowBal);

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        _farm(true);

        uint diffBalance = wantLockedInHere().add(supplyBal).sub(borrowBal).sub(prevBalance);
        balanceSnapshot.add(diffBalance);

        return diffBalance;
    }

    function farm(bool _withLev) public nonReentrant {
        _farm(_withLev);
    }

    function _farm(bool _withLev) internal {
        if(wantLockedInHere() > 1e18){
            if (wantIsWBNB) {
                _unwrapBNB();
                _leverage(address(this).balance, _withLev);
            } else {
                _leverage(wantLockedInHere(), _withLev);
            }
        }
        else{
            if (wantIsWBNB) {
                _unwrapBNB();
                _leverage(address(this).balance, false);
            } else {
                _leverage(wantLockedInHere(), false);
            }
        }

        updateBalance();

        deleverageUntilNotOverLevered();
    }

    function _leverage(uint256 _amount, bool _withLev) internal {
        if (_withLev) {
            for (uint256 i = 0; i < borrowDepth; i++) {
                _supply(_amount);
                _amount = _amount.mul(borrowRate).div(1000);
                _borrow(_amount);
            }
        }

        _supply(_amount);
    }

    function deleverageOnce() public {
        updateBalance();

        if (supplyBal <= supplyBalTargeted) {
            _removeSupply(supplyBal.sub(supplyBalMin));
        } else {
            _removeSupply(supplyBal.sub(supplyBalTargeted));
        }

        if (wantIsWBNB) {
            _unwrapBNB();
            _repayBorrow(address(this).balance);
        } else {
            _repayBorrow(wantLockedInHere());
        }

        updateBalance();
    }

    function deleverageUntilNotOverLevered() public {
        while (supplyBal > 0 && supplyBal <= supplyBalTargeted) {
            deleverageOnce();
        }
    }


    function _deleverage(bool _delevPartial, uint256 _minAmt) internal {
        updateBalance();

        deleverageUntilNotOverLevered();

        if (wantIsWBNB) {
            _wrapBNB();
        }

        _removeSupply(supplyBal.sub(supplyBalMin));

        uint256 wantBal = wantLockedInHere();

        while (wantBal < borrowBal) {

            if (_delevPartial && wantBal >= _minAmt) {
                return;
            }

            _repayBorrow(wantBal);

            updateBalance();

            _removeSupply(supplyBal.sub(supplyBalMin));

            wantBal = wantLockedInHere();
        }


        if (_delevPartial && wantBal >= _minAmt) {
            return;
        }

        _repayBorrow(borrowBal);

        uint256 vTokenBal = IERC20(vTokenAddress).balanceOf(address(this));
        IVToken(vTokenAddress).redeem(vTokenBal);
    }

    function rebalance(uint256 _borrowRate, uint256 _borrowDepth) external {
        require(msg.sender == govAddress, "Not authorised");

        require(_borrowRate <= BORROW_RATE_MAX, "!rate");
        require(_borrowDepth <= BORROW_DEPTH_MAX, "!depth");

        _deleverage(false, uint256(-1));
        borrowRate = _borrowRate;
        borrowDepth = _borrowDepth;
        _farm(true);
    }

    function earn() override external whenNotPaused {
    	updateBalance();
        uint256 wantBalance = wantLockedInHere().add(supplyBal).sub(borrowBal);
        uint256 earnedWantAmt = 0;
        if (wantBalance > balanceSnapshot){
        	earnedWantAmt = wantBalance.sub(balanceSnapshot);
        }

        IVenusDistribution(venusDistributionAddress).claimVenus(address(this));

        uint256 earnedAmt = IERC20(venusAddress).balanceOf(address(this));
        earnedAmt = buyBack(earnedAmt);

        if (venusAddress != wantAddress) {
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                earnedAmt,
                0,
                venusToWantPath,
                address(this),
                now.add(600)
            );
        }

        if(earnedWantAmt != 0){
        	buyBackWant(earnedWantAmt);
        }


        lastEarnBlock = block.number;
        _farm(false);

        wantBalance = wantLockedInHere().add(supplyBal).sub(borrowBal);
        if( wantBalance > balanceSnapshot ){
        	balanceSnapshot = wantBalance;
        }
    }

    function buyBackWant(uint256 _earnedWantAmt) internal returns (uint256) {
        if (_earnedWantAmt == 0) {
            return _earnedWantAmt;
        }    	

        uint256 buyBackAmt = _earnedWantAmt.mul(buyBackRate).div(buyBackRateMax);


    	uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        if (wantBal < buyBackAmt) {
            _deleverage(true, buyBackAmt);
            if (wantIsWBNB) {
                _wrapBNB();
            }
            wantBal = IERC20(wantAddress).balanceOf(address(this));
        }

        if (wantBal < buyBackAmt) {
            buyBackAmt = wantBal;
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

        return _earnedWantAmt.sub(buyBackAmt);
    }

    function buyBack(uint256 _earnedAmt) internal returns (uint256) {
        if (buyBackRate <= 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

        IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
            buyBackAmt,
            0,
            venusToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);

        return _earnedAmt.sub(buyBackAmt);
    }

    function withdraw(uint256 _wantAmt)
        override
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
    	updateBalance();
    	uint prevBalance = wantLockedInHere().add(supplyBal).sub(borrowBal);

    	_wantAmt = _wantAmt.mul( withdrawFeeRateMax.sub(withdrawFeeRate) ).div(withdrawFeeRateMax);

        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        if (wantBal < _wantAmt) {
            _deleverage(true, _wantAmt);
            if (wantIsWBNB) {
                _wrapBNB();
            }
            wantBal = IERC20(wantAddress).balanceOf(address(this));
        }

        if (wantBal < _wantAmt) {
            _wantAmt = wantBal;
        }

        IERC20(wantAddress).safeTransfer(owner(), _wantAmt);

        _farm(true);

        uint diffBalance = prevBalance.sub(wantLockedInHere().add(supplyBal).sub(borrowBal));
        balanceSnapshot = balanceSnapshot.sub(diffBalance);
        return _wantAmt;
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");

        _pause();

        IERC20(venusAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(uniRouterAddress, 0);
        if (!wantIsWBNB) {
            IERC20(wantAddress).safeApprove(vTokenAddress, 0);
        }
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();

        IERC20(venusAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        if (!wantIsWBNB) {
            IERC20(wantAddress).safeApprove(vTokenAddress, uint256(-1));
        }
    }


    function updateBalance() public {
        supplyBal = IVToken(vTokenAddress).balanceOfUnderlying(address(this));
        borrowBal = IVToken(vTokenAddress).borrowBalanceCurrent(address(this));
        supplyBalTargeted = borrowBal.mul(1000).div(borrowRate);
        supplyBalMin = borrowBal.mul(1000).div(BORROW_RATE_MAX_HARD);
    }

    function wantLockedTotal() override public view returns (uint256) {
        return wantLockedInHere().add(balanceSnapshot);
    }

    function wantLockedInHere() override public view returns (uint256) {
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        if (wantIsWBNB) {
            uint256 bnbBal = address(this).balance;
            return bnbBal.add(wantBal);
        } else {
            return wantBal;
        }
    }

    function setbuyBackRate(uint256 _buyBackRate) override public {
        require(msg.sender == govAddress, "Not authorised");
        require(buyBackRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
    }

    function setWithdrawFeeRate(uint256 _withdrawFeeRate) public {
        require(msg.sender == govAddress, "Not authorised");
        require(withdrawFeeRate <= withdrawFeeRateUL, "too high");
        withdrawFeeRate = _withdrawFeeRate;
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
        require(_token != earnedAddress, "!safe");
        require(_token != wantAddress, "!safe");
        require(_token != vTokenAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _wrapBNB() internal {
        uint256 bnbBal = address(this).balance;
        if (bnbBal > 0) {
            IWBNB(wbnbAddress).deposit{value: bnbBal}();
        }
    }

    function _unwrapBNB() internal {
        uint256 wbnbBal = IERC20(wbnbAddress).balanceOf(address(this));
        if (wbnbBal > 0) {
            IWBNB(wbnbAddress).withdraw(wbnbBal);
        }
    }

    function wrapBNB() public {
        require(msg.sender == govAddress, "Not authorised");
        require(wantIsWBNB, "!wantIsWBNB");
        _wrapBNB();
    }

    receive() external payable {}   
}