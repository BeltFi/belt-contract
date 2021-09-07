pragma solidity 0.6.12;

import "../StrategyV2.sol";
import "./StrategyVenusV3Storage.sol";
import "../../defi/venus.sol";
import "../../defi/pancake.sol";
import "../../../interfaces/Wrapped.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract StrategyVenusV3 is Initializable, StrategyV2, StrategyVenusV3Storage {
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

    function __StrategyVenusV3_init(
        address _BELTAddress,
        address _wantAddress,
        address _vTokenAddress,
        address _uniRouterAddress,
        address[] memory _venusToWantPath,
        address[] memory _venusToBELTPath
    ) public initializer {
        __StrategyV2_init(msg.sender, 5, 10000);
        __StrategyVenusV3_init_unchained(
            _BELTAddress,
            _wantAddress,
            _vTokenAddress,
            _uniRouterAddress,
            _venusToWantPath,
            _venusToBELTPath
        );
    }

    function __StrategyVenusV3_init_unchained(
        address _BELTAddress,
        address _wantAddress,
        address _vTokenAddress,
        address _uniRouterAddress,
        address[] memory _venusToWantPath,
        address[] memory _venusToBELTPath
    ) internal initializer {
        borrowRate = 585;

        BELTAddress = _BELTAddress;
        wantAddress = _wantAddress;

        if (wantAddress == wbnbAddress) {
            isWBNB = true;
        }

        venusToWantPath = _venusToWantPath;
        venusToBELTPath = _venusToBELTPath;

        vTokenAddress = _vTokenAddress;
        venusMarkets = [vTokenAddress];
        uniRouterAddress = _uniRouterAddress;


        IERC20(xvsAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        if (!isWBNB) {
            IERC20(wantAddress).safeApprove(vTokenAddress, uint256(-1));
        }

        IVenusDistribution(venusDistributionAddress).enterMarkets(venusMarkets);
    }


    function _supply(uint256 _amount) internal {
        if (isWBNB) {
            // venus checks and reverts on error internally
            _unwrapBNB();
            IVBNB(vTokenAddress).mint{value: _amount}();
        } else {
            require(IVToken(vTokenAddress).mint(_amount) == 0, "mint Venus Err");
        }
    }

    function _removeSupply(uint256 _amount) internal {
        require(IVToken(vTokenAddress).redeemUnderlying(_amount) == 0, "redeemUnderlying Venus Err");
        if (isWBNB) {
            _wrapBNB();
        }
    }

    function _borrow(uint256 _amount) internal {
        require(IVToken(vTokenAddress).borrow(_amount) == 0, "borrow Venus Err");
        if (isWBNB) {
            _wrapBNB();
        }
    }

    function _repayBorrow(uint256 _amount) internal {
        if (isWBNB) {
            // venus checks and reverts on error internally
            _unwrapBNB();
            IVBNB(vTokenAddress).repayBorrow{value: _amount}();
        } else {
            require(IVToken(vTokenAddress).repayBorrow(_amount) == 0, "repayBorrow Venus Err");
        }
    }

    function deposit(uint256 _wantAmt)
        public
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        (uint256 sup, uint256 brw, ) = updateBalance();

        uint prevBalance = wantLockedInHere().add(sup).sub(brw);

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        _supply(wantLockedInHere());

        (sup, brw, ) = updateBalance();
        uint diffBalance = wantLockedInHere().add(sup).sub(brw).sub(prevBalance);
        if (diffBalance > _wantAmt) {
            diffBalance = _wantAmt;
        }

        emit Deposit(wantAddress, _wantAmt, diffBalance);

        return diffBalance;
    }

    function leverage(uint256 _amount) public {
        require(govAddress == msg.sender || leverageAdmin == msg.sender, "Not authorized");
        _leverage(_amount);
    }

    function _leverage(uint256 _amount) internal {
        updateStrategy();
        (uint256 sup, uint256 brw, ) = updateBalance();

        require(
            brw.add(_amount).mul(1000).div(borrowRate) <= sup, "ltv too high"
        );
        _borrow(_amount);
        _supply(wantLockedInHere());
    }

    function deleverage(uint256 _amount) public {
        require(govAddress == msg.sender || leverageAdmin == msg.sender, "Not authorized");
        _deleverage(_amount);
    }

    function deleverageAll(uint256 redeemFeeAmt) public {
        require(govAddress == msg.sender || leverageAdmin == msg.sender, "Not authorized");
        updateStrategy();
        (uint256 sup, uint256 brw, uint256 supMin) = updateBalance();
        require(brw.add(redeemFeeAmt) <= sup.sub(supMin), "amount too big");
        _removeSupply(brw.add(redeemFeeAmt));
        _repayBorrow(brw);
        _supply(wantLockedInHere());
    }

    function _deleverage(uint256 _amount) internal {
        updateStrategy();
        (uint256 sup, uint256 brw, uint256 supMin) = updateBalance();

        require(_amount <= sup.sub(supMin), "amount too big");
        require(_amount <= brw, "amount too big");

        _removeSupply(_amount);
        _repayBorrow(wantLockedInHere());
    }

    function setBorrowRate(uint256 _borrowRate) external {
        require(msg.sender == govAddress, "Not authorised");
        updateStrategy();
        borrowRate = _borrowRate;
        (uint256 sup, , uint256 supMin) = updateBalance();
        require(sup >= supMin, "supply should be greater than supply min");
    }

    function earn() external whenNotPaused onlyEOA {
        IVenusDistribution(venusDistributionAddress).claimVenus(address(this));

        uint256 earnedAmt = IERC20(xvsAddress).balanceOf(address(this));
        if (earnedAmt != 0) {
            earnedAmt = buyBack(earnedAmt);

            if (xvsAddress != wantAddress) {
                IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                    earnedAmt,
                    0,
                    venusToWantPath,
                    address(this),
                    now.add(600)
                );
            }
        }

        lastEarnBlock = block.number;
        earnedAmt = wantLockedInHere();
        if (earnedAmt != 0) {
            _supply(earnedAmt);
        }
    }

    function buyBack(uint256 _earnedAmt) internal returns (uint256) {
        if (buyBackRate == 0 && buyBackPoolRate == 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate.add(buyBackPoolRate)).div(buyBackRateMax);

        IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
            buyBackAmt,
            0,
            venusToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this))
            .mul(buyBackPoolRate)
            .div(buyBackPoolRate.add(buyBackRate));
        if (burnAmt != 0) {
            IERC20(BELTAddress).safeTransfer(buyBackPoolAddress, burnAmt);
            emit Buyback(xvsAddress, _earnedAmt, buyBackAmt, BELTAddress, burnAmt, buyBackPoolAddress);
        }

        burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        if (burnAmt != 0) {
            IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);
            emit Buyback(xvsAddress, _earnedAmt, buyBackAmt, BELTAddress, burnAmt, buyBackAddress);
        }

        return _earnedAmt.sub(buyBackAmt);
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

        _withdraw(_wantAmt);

        uint256 wantBal = wantLockedInHere();
        IERC20(wantAddress).safeTransfer(owner(), wantBal);

        emit Withdraw(wantAddress, _wantAmt, wantBal);
        
        return wantBal;
    }

    function _withdraw(uint256 _wantAmt) internal {
    	(uint256 sup, uint256 brw, uint256 supMin) = updateBalance();
        uint256 delevAmtAvail = sup.sub(supMin);
        while (_wantAmt > delevAmtAvail) {
            if (delevAmtAvail > brw) {
                _deleverage(brw);
                (sup, brw, supMin) = updateBalance();
                delevAmtAvail = sup.sub(supMin);
                break;  
            } else {
                _deleverage(delevAmtAvail);
            }
            (sup, brw, supMin) = updateBalance();  
            delevAmtAvail = sup.sub(supMin);
        }

        if (_wantAmt > delevAmtAvail) {
            _wantAmt = delevAmtAvail;
        }

        _removeSupply(_wantAmt);
    }

    function _pause() override internal {
        super._pause();
        IERC20(xvsAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(uniRouterAddress, 0);
        if (!isWBNB) {
            IERC20(wantAddress).safeApprove(vTokenAddress, 0);
        }
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function _unpause() override internal {
        super._unpause();
        IERC20(xvsAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        if (!isWBNB) {
            IERC20(wantAddress).safeApprove(vTokenAddress, uint256(-1));
        }
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();
    }

    function updateBalance() public view returns (uint256 sup, uint256 brw, uint256 supMin) {
        (uint256 errCode, uint256 _sup, uint256 _brw, uint exchangeRate) = IVToken(vTokenAddress).getAccountSnapshot(address(this));
        require(errCode == 0, "Venus ErrCode");
        sup = _sup.mul(exchangeRate).div(1e18);
        brw = _brw;
        supMin = brw.mul(1000).div(borrowRate);
    }

    function wantLockedTotal() public view returns (uint256) {
        (uint256 sup, uint256 brw, ) = updateBalance();
        return wantLockedInHere().add(sup).sub(brw);
    }

    function wantLockedInHere() public view returns (uint256) {
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        return wantBal;
    }

    function setbuyBackRate(uint256 _buyBackRate, uint256 _buyBackPoolRate) public {
        require(msg.sender == govAddress, "Not authorised");
        require(_buyBackRate <= buyBackRateUL, "too high");
        require(_buyBackPoolRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
        buyBackPoolRate = _buyBackPoolRate;
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
            IUnwrapper(bnbHelper).unwrapBNB(wbnbBal);
        }
    }

    function wrapBNB() public {
        require(msg.sender == govAddress, "Not authorised");
        require(isWBNB, "!isWBNB");
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

    function setXVSToWantPath(address[] memory newPath) public {
        require(msg.sender == govAddress, "Not authorised");
        venusToWantPath = newPath;
    }

    function updateStrategy() public {
        require(IVToken(vTokenAddress).accrueInterest() == 0);
    }

    function setLeverageAdmin(address _leverageAdmin) external {
        require(msg.sender == govAddress, "Not authorized");
        leverageAdmin = _leverageAdmin;
    }

    function setbuyBackPoolAddress(address _buyBackPoolAddress) external {
        require(msg.sender == govAddress, "Not authorised");
        require(_buyBackPoolAddress != address(0));
        require(_buyBackPoolAddress != buyBackPoolAddress);
        if (buyBackPoolAddress != address(0)) {
            IERC20(BELTAddress).safeApprove(buyBackPoolAddress, 0);
        }
        IERC20(BELTAddress).safeApprove(_buyBackPoolAddress, uint256(-1));
        buyBackPoolAddress = _buyBackPoolAddress;
    }

    fallback() external payable {}

    receive() external payable {}
}
