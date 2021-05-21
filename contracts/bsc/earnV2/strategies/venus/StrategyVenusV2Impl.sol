pragma solidity 0.6.12;

import "./StrategyVenusV2Storage.sol";
import "../../defi/venus.sol";
import "../../defi/pancake.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

interface HelperLike {
    function unwrapBNB(uint256) external;
}

contract StrategyVenusV2Impl is StrategyVenusV2Storage {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    function _supply(uint256 _amount) internal {
        if (wantIsWBNB) {
            // venus checks and reverts on error internally
            IVBNB(vTokenAddress).mint{value: _amount}();
        } else {
            require(IVToken(vTokenAddress).mint(_amount) == 0);
        }
    }

    function _removeSupply(uint256 _amount) internal {
        require(IVToken(vTokenAddress).redeemUnderlying(_amount) == 0);
    }

    function _borrow(uint256 _amount) internal {
        require(IVToken(vTokenAddress).borrow(_amount) == 0);
    }

    function _repayBorrow(uint256 _amount) internal {
        if (wantIsWBNB) {
            // venus checks and reverts on error internally
            IVBNB(vTokenAddress).repayBorrow{value: _amount}();
        } else {
            require(IVToken(vTokenAddress).repayBorrow(_amount) == 0);
        }
    }

    function deposit(uint256 _wantAmt)
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


    function _deleverage(bool _delevPartial, uint256 _amt, uint256 _minAmt) internal {
        updateBalance();

        deleverageUntilNotOverLevered();

        if (wantIsWBNB) {
            _wrapBNB();
        }

        if (_amt <= supplyBal.sub(supplyBalMin)) {
            _removeSupply(_amt);
        } else {
            revert("no leverage allowed");
        }

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

        revert("no leverage allowed");
    }

    function rebalance(uint256 _borrowRate, uint256 _borrowDepth) external {
        require(msg.sender == govAddress, "Not authorised");

        require(_borrowRate <= BORROW_RATE_MAX, "!rate");
        require(_borrowRate != 0, "borrowRate is used as a divisor");
        require(_borrowDepth <= BORROW_DEPTH_MAX, "!depth");

        _deleverage(false, uint256(-1), uint256(-1));
        borrowRate = _borrowRate;
        borrowDepth = _borrowDepth;
        _farm(true);
    }

    function earn() external whenNotPaused {
    	updateBalance();
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



        lastEarnBlock = block.number;
        _farm(false);
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
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
    	updateBalance();

        uint256 _wantAmtWithFee = _wantAmt;
        _wantAmt = _wantAmt.mul(
            withdrawFeeDenom.sub(withdrawFeeNumer)
        ).div(withdrawFeeDenom);

        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        if (wantBal < _wantAmt) {
            _deleverage(true, _wantAmtWithFee, _wantAmt);
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

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere().add(
            supplyBal
        ).sub(
            borrowBal
        );
    }

    function wantLockedInHere() public view returns (uint256) {
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        if (wantIsWBNB) {
            uint256 bnbBal = address(this).balance;
            return bnbBal.add(wantBal);
        } else {
            return wantBal;
        }
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
            IERC20(wbnbAddress).safeApprove(bnbHelper, wbnbBal);
            HelperLike(bnbHelper).unwrapBNB(wbnbBal);
        }
    }

    function wrapBNB() public {
        require(msg.sender == govAddress, "Not authorised");
        require(wantIsWBNB, "!wantIsWBNB");
        _wrapBNB();
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

    function setBNBHelper(address _helper) public {
        require(msg.sender == govAddress, "!gov");
        require(_helper != address(0));

        bnbHelper = _helper;
    }

    function setPancakeRouterV2() public {
        require(msg.sender == govAddress, "!gov");
        uniRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }

    fallback() external payable {}

    receive() external payable {}
}
