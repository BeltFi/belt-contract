pragma solidity 0.6.12;

import "./SingleStrategyTokenStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface StrategyLike {
    function wantLockedTotal() external view returns (uint256);

    function wantLockedInHere() external view returns (uint256);
    
    function deposit(uint256 _wantAmt) external returns (uint256);

    function withdraw(uint256 _wantAmt) external returns (uint256);
}

interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

interface HelperLike {
    function unwrapBNB(uint256) external;
}

contract SingleStrategyTokenImpl2 is SingleStrategyTokenStorage {
    using SafeERC20 for IERC20;

    constructor () public ERC20("", "") {}

    function setGovAddress(address _govAddress) external {
        require(msg.sender == govAddress, "Not authorized");
        govAddress = _govAddress;
    }

    function pauseDeposit() external {
        require(!depositPaused, "deposit paused");
        require(msg.sender == govAddress, "Not authorized");
        depositPaused = true;
    }

    function unpauseDeposit() external {
        require(depositPaused, "deposit not paused");
        require(msg.sender == govAddress, "Not authorized");
        depositPaused = false;
    }

    function pauseWithdraw() external virtual {
        require(!withdrawPaused, "withdraw paused");
        require(msg.sender == govAddress, "Not authorized");
        withdrawPaused = true;
    }

    function unpauseWithdraw() external virtual {
        require(withdrawPaused, "withdraw not paused");
        require(msg.sender == govAddress, "Not authorized");
        withdrawPaused = false;
    }

    function depositBnb(uint256 _minShares) external payable {
        require(!depositPaused, "deposit paused");
        require(isWbnb, "not bnb");
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

    function _deposit(uint256 _amount, uint256 _minShares) internal {
        uint256 _pool = calcPoolValueInToken();
        uint256 sharesToMint = StrategyLike(strategy).deposit(_amount);
        if (totalSupply() != 0 && _pool != 0) {
            sharesToMint = (sharesToMint.mul(totalSupply()))
            .div(_pool);
        }
        require(sharesToMint >= _minShares, "did not meet minimum shares requested");
        _mint(msg.sender, sharesToMint);
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

        uint256 r = sharesToAmount(_shares);
        _burn(msg.sender, _shares);

        r = StrategyLike(strategy).withdraw(r);

        require(r >= _minAmount, "did not meet minimum amount requested");
        
        return r;
    }

    function balance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceStrategy() public view returns (uint256) {
        return StrategyLike(strategy).wantLockedTotal();        
    }

    function calcPoolValueInToken() public view returns (uint) {
        return balanceStrategy();
    }

    function getPricePerFullShare() public view returns (uint) {
        uint256 _pool = calcPoolValueInToken();
        return _pool.mul(uint256(10) ** uint256(decimals())).div(totalSupply());
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
            HelperLike(bnbHelper).unwrapBNB(_amount);
        }
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != address(this), "!safe");
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "amount greater than holding");
            _wrapBNB(_amount);
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
        require(msg.sender == govAddress, "!gov");
        require(_helper != address(0));

        bnbHelper = _helper;
    }

    fallback() external payable {}
    receive() external payable {}
}
