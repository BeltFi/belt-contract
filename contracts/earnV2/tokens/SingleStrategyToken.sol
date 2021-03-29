pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./StrategyToken.sol";
import "../strategies/Strategy.sol";

interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

contract SingleStrategyToken is StrategyToken {

    address public strategy;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    bool public immutable isWbnb;

    constructor (string memory name_, string memory symbol_, address _token, address _strategy) public ERC20(name_, symbol_) {
        token = _token;
        strategy = _strategy;
        govAddress = msg.sender;
        entranceFeeNumer = 1;
        entranceFeeDenom = 1000;

        isWbnb = token == wbnbAddress;

        approveToken();
    }

    function depositBNB(uint256 _minShares) external payable {
        require(isWbnb);
        require(msg.value != 0, "deposit must be greater than 0");
        _deposit(msg.value, _minShares);
        _wrapBNB(msg.value);
    }

    function deposit(uint256 _amount, uint256 _minShares) override external {
        require(_amount != 0, "deposit must be greater than 0");
        _deposit(_amount, _minShares);
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function _deposit(uint256 _amount, uint256 _minShares) internal nonReentrant {
        uint256 shares = amountToShares(_amount);
        require(shares >= _minShares);
        _mint(msg.sender, shares);
    }

    function withdraw(uint256 _shares, uint256 _minAmount) override external {
        uint256 r = _withdraw(_shares, _minAmount);
        IERC20(token).safeTransfer(msg.sender, r);
    }

    function withdrawBNB(uint256 _shares, uint256 _minAmount) external {
        require(isWbnb);
        uint256 r = _withdraw(_shares, _minAmount);
        _unwrapBNB(r);
        msg.sender.transfer(r);
    }

    function _withdraw(uint256 _shares, uint256 _minAmount)
        internal
        nonReentrant
        returns (uint256)
    {
        require(_shares != 0, "shares must be greater than 0");

        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");

        uint256 r = sharesToAmount(_shares);
        _burn(msg.sender, _shares);

        uint256 b = balance();
        if (b < r) {
            // require(balanceStrategy() >= r.sub(b));
            Strategy(strategy).withdraw(r.sub(b));
            r = balance();
        }

        require(r >= _minAmount);
        
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

    function supplyStrategy() public {
        uint256 before = balance();
        uint256 supplied = Strategy(strategy).deposit(balance());
        require(supplied >= before.mul(entranceFeeDenom.sub(entranceFeeNumer)).div(entranceFeeDenom));
    }

    function calcPoolValueInToken() override public view returns (uint) {
        return balanceStrategy()
            .add(balance());
    }

    function getPricePerFullShare() override public view returns (uint) {
        uint256 _pool = calcPoolValueInToken();
        return _pool.mul(uint256(10) ** uint256(decimals())).div(totalSupply());
    }

    function setGovAddress(address _govAddress) override public {
        require(msg.sender == govAddress, "Not authorized");
        govAddress = _govAddress;
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

    function setEntranceFee(uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) override external {
        require(msg.sender == govAddress, "Not authorized");
        require(_entranceFeeDenom != 0);
        require(_entranceFeeNumer.mul(10) <= _entranceFeeDenom);
        entranceFeeNumer = _entranceFeeNumer;
        entranceFeeDenom = _entranceFeeDenom;
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

    receive() external payable {}
}
