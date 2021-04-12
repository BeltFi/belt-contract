pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./StrategyToken.sol";
import "../strategies/Strategy.sol";

interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

contract SingleStrategyToken2 is StrategyToken {

    address public strategy;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    bool public immutable isWbnb;

    constructor (string memory name_, string memory symbol_, address _token, address _strategy) public ERC20(name_, symbol_) {
        token = _token;
        strategy = _strategy;
        govAddress = msg.sender;
        entranceFeeNumer = 0;
        entranceFeeDenom = 1;

        isWbnb = token == wbnbAddress;

        approveToken();
    }

    function depositBnb(uint256 _minShares) external payable {
        require(!depositPaused, "deposit paused");
        require(isWbnb, "not bnb");
        require(msg.value != 0, "deposit must be greater than 0");
        _wrapBNB(msg.value);
        _deposit(msg.value, _minShares);
    }

    function deposit(uint256 _amount, uint256 _minShares) override external {
        require(!depositPaused, "deposit paused");
        require(_amount != 0, "deposit must be greater than 0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_amount, _minShares);
    }

    function _deposit(uint256 _amount, uint256 _minShares) internal {
        uint256 _pool = calcPoolValueInToken();
        uint256 sharesToMint = Strategy(strategy).deposit(_amount);
        if (totalSupply() != 0 && _pool != 0) {
            sharesToMint = (sharesToMint.mul(totalSupply()))
            .div(_pool);
        }
        require(sharesToMint >= _minShares, "did not meet minimum shares requested");
        _mint(msg.sender, sharesToMint);
    }

    function withdraw(uint256 _shares, uint256 _minAmount) override external {
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

        r = Strategy(strategy).withdraw(r);

        require(r >= _minAmount, "did not meet minimum amount requested");
        
        return r;
    }

    function approveToken() public {
        IERC20(token).safeApprove(strategy, uint(-1));
    }

    function balance() override public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceStrategy() override public view returns (uint256) {
        return Strategy(strategy).wantLockedTotal();        
    }

    function calcPoolValueInToken() override public view returns (uint) {
        return balanceStrategy();
    }

    function getPricePerFullShare() override public view returns (uint) {
        uint256 _pool = calcPoolValueInToken();
        return _pool.mul(uint256(10) ** uint256(decimals())).div(totalSupply());
    }

    function sharesToAmount(uint256 _shares) override public view returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        return _shares.mul(_pool).div(totalSupply());
    }

    function amountToShares(uint256 _amount) override public view returns (uint256) {
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

    function setEntranceFee(uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) override external {
        revert();
        // require(msg.sender == govAddress, "Not authorized");
        // require(_entranceFeeNumer.mul(10) <= _entranceFeeDenom);
        // entranceFeeNumer = _entranceFeeNumer;
        // entranceFeeDenom = _entranceFeeDenom;
    }

    function _wrapBNB(uint256 _amount) internal {
        if (address(this).balance >= _amount) {
            IWBNB(wbnbAddress).deposit{value: _amount}();
        }
    }

    function _unwrapBNB(uint256 _amount) internal {
        uint256 wbnbBal = IERC20(wbnbAddress).balanceOf(address(this));
        if (wbnbBal >= _amount) {
            IWBNB(wbnbAddress).withdraw(_amount);
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

    receive() external payable {}
}
