pragma solidity 0.6.12;

import "../StrategyV2.sol";
import "./StrategyFortubeV2Storage.sol";
import "../../defi/fortube.sol";
import "../../defi/pancake.sol";
import "../../../interfaces/Wrapped.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract StrategyFortubeV2 is Initializable, StrategyV2, StrategyFortubeV2Storage {
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

    function __StrategyFortubeV2_init(
        address _BELTAddress,
        address _wantAddress,
        address _fTokenAddress,
        address _uniRouterAddress,
        address[] memory _forToWantPath,
        address[] memory _forToBELTPath
    ) public initializer {
        __StrategyV2_init(msg.sender, 5, 10000);
        __StrategyFortubeV2_init_unchained(
            _BELTAddress,
            _wantAddress,
            _fTokenAddress,
            _uniRouterAddress,
            _forToWantPath,
            _forToBELTPath
        );
    }
    
    function __StrategyFortubeV2_init_unchained(
        address _BELTAddress,
        address _wantAddress,
        address _fTokenAddress,
        address _uniRouterAddress,
        address[] memory _forToWantPath,
        address[] memory _forToBELTPath
    ) internal initializer {
        borrowRate = 585;

        BELTAddress = _BELTAddress;
        wantAddress = _wantAddress;

        if (wantAddress == wbnbAddress) {
            isWBNB = true;
        }

        forToWantPath = _forToWantPath;
        forToBELTPath = _forToBELTPath;


        fTokenAddress = _fTokenAddress;
        fortubeMarkets = [fTokenAddress];
        uniRouterAddress = _uniRouterAddress;  


        IERC20(forAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(bankControllerAddress, uint256(-1));
    }

    function _supply(uint256 _amount) internal {
        if (isWBNB) {
            _unwrapBNB();
            IBank(bankAddress).deposit{value: _amount}(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB, _amount);
        } else {
            IBank(bankAddress).deposit(wantAddress, _amount);
        }
    }

    function _removeSupply(uint256 _amount) internal {
        if (isWBNB) {
            IBank(bankAddress).withdrawUnderlying(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB, _amount);
            _wrapBNB();
        } else {
            IBank(bankAddress).withdrawUnderlying(wantAddress, _amount);
        }
    }

    function _borrow(uint256 _amount) internal {
        if (isWBNB) {
            IBank(bankAddress).borrow(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB, _amount);
            _wrapBNB();
        } else {
            IBank(bankAddress).borrow(wantAddress, _amount);
        }
    }

    function _repayBorrow(uint256 _amount) internal {
        if (isWBNB) {
            _unwrapBNB();
            IBank(bankAddress).repay{value: _amount}(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB, _amount);
        } else {
            IBank(bankAddress).repay(wantAddress, _amount);
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
        require(sup >= supMin, "supply should be greater than min supply");
    }

    function earn() external whenNotPaused onlyEOA {
        if (IMiningReward(forDistributionAddress).checkBalance(address(this)) > 0) {
            IMiningReward(forDistributionAddress).claimReward();

            uint256 earnedAmt = IERC20(forAddress).balanceOf(address(this));
            earnedAmt = buyBack(earnedAmt);

            if (forAddress != wantAddress) {
                IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                    earnedAmt,
                    0,
                    forToWantPath,
                    address(this),
                    now.add(600)
                );
            }
        }
        lastEarnBlock = block.number;
        if (wantLockedInHere() != 0) {
            _supply(wantLockedInHere());
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
            forToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);
        emit Buyback(forAddress, _earnedAmt, buyBackAmt, BELTAddress, burnAmt, buyBackAddress);

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
        uint256 sup;
        uint256 brw;
        uint256 supMin;
    	(sup, brw, supMin) = updateBalance();

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
        IERC20(forAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(bankControllerAddress, 0);
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function _unpause() override internal {
        super._unpause();
        IERC20(forAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(bankControllerAddress, uint256(-1));
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();
    }


    function updateBalance() public view returns (uint256 sup, uint256 brw, uint256 supMin) {
        sup = IFToken(fTokenAddress).calcBalanceOfUnderlying(address(this));
        brw = IFToken(fTokenAddress).borrowBalanceStored(address(this));

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
        require(_token != fTokenAddress, "!safe");

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

    function setForToWantPath(address[] memory newPath) public {
        require(msg.sender == govAddress, "Not authorised");
        forToWantPath = newPath;
    }

    function updateStrategy() public {
        _supply(0);
    }

    function setLeverageAdmin(address _leverageAdmin) external {
        require(msg.sender == govAddress, "Not authorized");
        leverageAdmin = _leverageAdmin;
    }

    fallback() external payable {}

    receive() external payable {}
}
