pragma solidity 0.6.12;

import "./SingleStrategyTokenStorage.sol";
import "../../interfaces/Wrapped.sol";
import "../../interfaces/IStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract SingleStrategyTokenImpl is SingleStrategyTokenStorage {
    using SafeERC20 for IERC20;

    event Deposit(address tokenAddress, uint256 depositAmount, uint256 sharesMinted);
    event Withdraw(address tokenAddress, uint256 withdrawAmount, uint256 sharesBurnt);
    event Supply(uint256 amountSupplied, uint256 amountDeposited);
    event EntranceFeeSet(uint256 numer, uint256 denom);
    event DepositPause(address account, bool paused);
    event WithdrawPause(address account, bool paused);

    constructor () public ERC20("", "") {}

    function setGovAddress(address _govAddress) external {
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        govAddress = _govAddress;
    }

    function pauseDeposit() external {
        require(!depositPaused, "deposit paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        depositPaused = true;
        emit DepositPause(msg.sender, true);
    }

    function unpauseDeposit() external {
        require(depositPaused, "deposit not paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        depositPaused = false;
        emit DepositPause(msg.sender, false);
    }

    function pauseWithdraw() external virtual {
        require(!withdrawPaused, "withdraw paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        withdrawPaused = true;
        emit WithdrawPause(msg.sender, true);
    }

    function unpauseWithdraw() external virtual {
        require(withdrawPaused, "withdraw not paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        withdrawPaused = false;
        emit WithdrawPause(msg.sender, false);
    }

    function depositBNB(uint256 _minShares) external payable {
        require(!depositPaused, "deposit paused");
        require(isWbnb, "not bnb");
        require(msg.value != 0, "deposit must be greater than 0");
        _deposit(msg.value, _minShares);
        _wrapBNB(msg.value);
    }

    function deposit(uint256 _amount, uint256 _minShares) external {
        require(!depositPaused, "deposit paused");
        require(_amount != 0, "deposit must be greater than 0");
        _deposit(_amount, _minShares);
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function _deposit(uint256 _amount, uint256 _minShares) internal nonReentrant {
        IStrategy(strategy).updateStrategy();
        uint256 shares = amountToShares(_amount);
        require(shares >= _minShares, "did not meet minimum shares requested");
        _mint(msg.sender, shares);
        emit Deposit(token, _amount, shares);
    }

    function withdraw(uint256 _shares, uint256 _minAmount) external {
        uint256 r = _withdraw(_shares, _minAmount);
        IERC20(token).safeTransfer(msg.sender, r);
    }

    function withdrawBNB(uint256 _shares, uint256 _minAmount) external {
        require(isWbnb, "not bnb");
        uint256 r = _withdraw(_shares, _minAmount);
        _unwrapBNB(r);
        msg.sender.transfer(r);
    }

    function _withdraw(uint256 _shares, uint256 _minAmount)
        internal
        nonReentrant
        returns (uint256)
    {
        require(!withdrawPaused, "withdraw paused");
        require(_shares != 0, "shares must be greater than 0");

        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");

        updateStrategy();
        uint256 r = sharesToAmount(_shares);
        _burn(msg.sender, _shares);

        uint256 b = balance();
        if (b < r) {
            // require(balanceStrategy() >= r.sub(b));
            IStrategy(strategy).withdraw(r.sub(b));
            r = balance();
        }

        require(r >= _minAmount, "did not meet minimum amount requested");

        emit Withdraw(token, r, _shares);
        
        return r;
    }

    function balance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceStrategy() public view returns (uint256) {
        return IStrategy(strategy).wantLockedTotal();        
    }

    function supplyStrategy() public {
        updateStrategy();
        uint256 before = balance();
        uint256 supplied = IStrategy(strategy).deposit(balance());
        require(supplied >= before.mul(entranceFeeDenom.sub(entranceFeeNumer)).div(entranceFeeDenom), "Amount supplied too small");
        emit Supply(before, supplied);
    }

    function calcPoolValueInToken() public view returns (uint) {
        return balanceStrategy()
            .add(balance());
    }

    function updateStrategy() public {
        IStrategy(strategy).updateStrategy();
    }

    function getPricePerFullShare() public view returns (uint) {
        uint256 _pool = calcPoolValueInToken();
        return _pool.mul(1e18).div(totalSupply());
    }

    function sharesToAmount(uint256 _shares) public view returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        return _shares.mul(_pool).div(totalSupply());
    }

    function amountToShares(uint256 _amount) public view returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        uint256 shares;
        if (totalSupply() == 0 || _pool == 0) {
            shares = _amount;
        } else {
            //0.1%(999/1000) enterance fee
            shares = (_amount.mul(totalSupply()))
            .mul(
                entranceFeeDenom.sub(entranceFeeNumer)
            )
            .div(_pool)
            .div(entranceFeeDenom);
        }
        return shares;
    }

    function setEntranceFee(uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) external {
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        require(_entranceFeeDenom != 0, "denominator should not be 0");
        require(_entranceFeeNumer.mul(10) <= _entranceFeeDenom, "numerator value too big");
        entranceFeeNumer = _entranceFeeNumer;
        entranceFeeDenom = _entranceFeeDenom;

        emit EntranceFeeSet(entranceFeeNumer, entranceFeeDenom);
    }

    function _wrapBNB(uint256 _amount) internal {
        if (address(this).balance >= _amount) {
            IWBNB(wbnbAddress).deposit{value: _amount}();
        }
    }

    function _unwrapBNB(uint256 _amount) internal {
        uint256 wbnbBal = IERC20(wbnbAddress).balanceOf(address(this));
        if (wbnbBal >= _amount) {
            IERC20(wbnbAddress).safeApprove(bnbHelper, _amount);
            IUnwrapper(bnbHelper).unwrapBNB(_amount);
        }
    }

    function getProxyAdmin() public view returns (address adm) {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            adm := sload(slot)
        }
    }

    function setBNBHelper(address _helper) public {
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        require(_helper != address(0));

        bnbHelper = _helper;
    }

    fallback() external payable {}
    receive() external payable {}
}
