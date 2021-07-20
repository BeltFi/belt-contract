pragma solidity 0.6.12;

import "./StrategyTokenV2.sol";
import "./SingleStrategyTokenStorageV2.sol";
import "../../interfaces/Wrapped.sol";
import "../../interfaces/IStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract SingleStrategyToken2V2 is Initializable, StrategyTokenV2, SingleStrategyTokenStorageV2 {
    using SafeERC20 for IERC20;

    event Deposit(address tokenAddress, uint256 depositAmount, uint256 sharesMinted);
    event Withdraw(address tokenAddress, uint256 withdrawAmount, uint256 sharesBurnt);

    function __SingleStrategyToken2V2_init(
        string memory name_,
        string memory symbol_,
        address _token,
        address _strategy
    ) public initializer {
        __StrategyTokenV2_init(name_, symbol_, _token, msg.sender, 0, 1);
        __SingleStrategyToken2V2_init_unchained(_strategy);
    }

    function __SingleStrategyToken2V2_init_unchained(address _strategy) internal initializer {
        strategy = _strategy;
        approveToken();
    }

    function approveToken() public {
        IERC20(token).safeApprove(strategy, uint(-1));
    }

    function setGovAddress(address _govAddress) external {
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        govAddress = _govAddress;
    }

    function pauseDeposit() external {
        require(!depositPaused, "deposit paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        depositPaused = true;
    }

    function unpauseDeposit() external {
        require(depositPaused, "deposit not paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        depositPaused = false;
    }

    function pauseWithdraw() external virtual {
        require(!withdrawPaused, "withdraw paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        withdrawPaused = true;
    }

    function unpauseWithdraw() external virtual {
        require(withdrawPaused, "withdraw not paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        withdrawPaused = false;
    }

    function depositBNB(uint256 _minShares) external payable {
        require(!depositPaused, "deposit paused");
        require(isWBNB, "not bnb");
        require(msg.value != 0, "deposit must be greater than 0");
        _wrapBNB(msg.value);
        _deposit(msg.value, _minShares);
    }

    function deposit(uint256 _amount, uint256 _minShares) external {
        require(!depositPaused, "deposit paused");
        require(_amount != 0, "deposit must be greater than 0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_amount, _minShares);
    }

    function _deposit(uint256 _amount, uint256 _minShares) internal nonReentrant {
        IStrategy(strategy).updateStrategy();
        uint256 _pool = calcPoolValueInToken();
        uint256 sharesToMint = IStrategy(strategy).deposit(_amount);
        if (totalSupply() != 0 && _pool != 0) {
            sharesToMint = (sharesToMint.mul(totalSupply()))
            .div(_pool);
        }
        require(sharesToMint >= _minShares, "did not meet minimum shares requested");
        _mint(msg.sender, sharesToMint);
        emit Deposit(token, _amount, sharesToMint);
    }

    function withdraw(uint256 _shares, uint256 _minAmount) external {
        uint256 r = _withdraw(_shares, _minAmount);
        IERC20(token).safeTransfer(msg.sender, r);
    }

    function withdrawBNB(uint256 _shares, uint256 _minAmount) external {
        require(isWBNB, "not bnb");
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

        IStrategy(strategy).updateStrategy();
        uint256 r = sharesToAmount(_shares);
        _burn(msg.sender, _shares);

        r = IStrategy(strategy).withdraw(r);

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

    function calcPoolValueInToken() public view returns (uint) {
        return balanceStrategy();
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
            shares = (_amount.mul(totalSupply()))
                .div(_pool);
        }
        return shares;
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

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        require(_token != address(this), "!safe");
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "amount greater than holding");
            _wrapBNB(_amount);
            _token = wbnbAddress;
        } else if (_token == token) { 
            require(balance() >= _amount, "amount greater than holding");
        }
        IERC20(_token).safeTransfer(_to, _amount);
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
