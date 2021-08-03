pragma solidity 0.6.12;

import "./StrategyAlpacaStorage.sol";
import "../../defi/alpaca.sol";
import "../../defi/pancake.sol";
import "../../../interfaces/Wrapped.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract StrategyAlpacaImpl is StrategyAlpacaStorage {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    event Deposit(address wantAddress, uint256 amountReceived, uint256 amountDeposited);
    event Withdraw(address wantAddress, uint256 amountRequested, uint256 amountWithdrawn);    
    event BuybackWant(address wantAddress, uint256 earnedAmount, uint256 buybackAmount, address buybackTokenAddress, uint256 burnAmount, address buybackAddress);
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

        uint256 before = _stakedWantTokens();
        _deposit(_wantAmt);
        uint256 diff = _stakedWantTokens().sub(before);
        if (diff > _wantAmt) {
            diff = _wantAmt;
        }

        balanceSnapshot = balanceSnapshot.add(diff);

        emit Deposit(wantAddress, _wantAmt, diff);

        return diff;
    }

    function _deposit(uint _wantAmt) internal {
        if(isWbnb) {
            _unwrapBNB();
            Vault(vaultAddress).deposit{value: _wantAmt}(_wantAmt);
            _wrapBNB();
        } else {
            Vault(vaultAddress).deposit(_wantAmt);
        }
        FairLaunch(fairLaunchAddress).deposit(address(this), poolId, Vault(vaultAddress).balanceOf(address(this)));
    }

    function earn() external whenNotPaused onlyEOA {
        FairLaunch(fairLaunchAddress).harvest(poolId);

        uint256 earnedAmt = AlpacaToken(alpacaAddress).balanceOf(address(this));
        earnedAmt = buyBack(earnedAmt);

        if (alpacaAddress != wantAddress) {
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                earnedAmt,
                0,
                alpacaToWantPath,
                address(this),
                now.add(600)
            );
        }

        uint256 prevBalance = balanceSnapshot;
        uint256 currentBalance = _stakedWantTokens();

        if (currentBalance > prevBalance) {
            earnedAmt = currentBalance.sub(prevBalance);
            buyBackWant(earnedAmt);
        }

        earnedAmt = IERC20(wantAddress).balanceOf(address(this));
        if (earnedAmt != 0) {
            _deposit(earnedAmt);
        }
        balanceSnapshot = _stakedWantTokens();
        
        lastEarnBlock = block.number;
    }

    function buyBackWant(uint256 _earnedAmt) internal {
        if (buyBackRate != 0) {
            uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

            if(isWbnb) {
                _wrapBNB();
            }

            uint256 curWantBal = wantLockedInHere();

            if (curWantBal < buyBackAmt) {
                _withdraw(buyBackAmt.sub(curWantBal));
                if(isWbnb) {
                    _wrapBNB();
                }
                if (wantLockedInHere() < buyBackAmt) {
                    buyBackAmt = wantLockedInHere();
                }
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
            emit BuybackWant(wantAddress, _earnedAmt, buyBackAmt, BELTAddress, burnAmt, buyBackAddress);
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
            alpacaToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);
        emit Buyback(alpacaAddress, _earnedAmt, buyBackAmt, BELTAddress, burnAmt, buyBackAddress);
        
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
        
        uint wantBal;

        if(_wantAmt > wantLockedInHere()) {
            _withdraw(_wantAmt.sub(
                wantLockedInHere()
            ));
        }
        
        if(isWbnb) {
            _wrapBNB();
        }

        wantBal = IERC20(wantAddress).balanceOf(address(this));
        
        if (wantBal > _wantAmt) {
            wantBal = _wantAmt;
        }

        IERC20(wantAddress).safeTransfer(owner(), wantBal);

        balanceSnapshot = balanceSnapshot.sub(_wantAmt);

        emit Withdraw(wantAddress, _wantAmt, wantBal);

        return wantBal;
    }

    function _withdraw(uint256 _wantAmt) internal {
        uint256 amount = _wantAmt.mul(Vault(vaultAddress).totalSupply()).div(Vault(vaultAddress).totalToken());
        FairLaunch(fairLaunchAddress).withdraw(address(this), poolId, amount);
        Vault(vaultAddress).withdraw(Vault(vaultAddress).balanceOf(address(this)));
    }

    function _stakedWantTokens() public view returns (uint256) {
        (uint256 _amount, , ,) = FairLaunch(fairLaunchAddress).userInfo(poolId, address(this));
        return _amount.mul(Vault(vaultAddress).totalToken()).div(Vault(vaultAddress).totalSupply());
    }

    function _pause() override internal {
        super._pause();
        
        IERC20(alpacaAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(vaultAddress, 0);
    }

    function pause() external {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function _unpause() override internal {
        super._unpause();
        
        IERC20(alpacaAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(vaultAddress, uint256(-1));
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();
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

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != alpacaAddress, "!safe");
        require(_token != wantAddress, "!safe");
        require(_token != vaultAddress, "!safe");

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

    function updateStrategy() public {
    }

    fallback() external payable {}

    receive() external payable {}
}
