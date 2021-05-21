pragma solidity 0.6.12;

contract ReentrancyGuard {
    uint256 private _guardCounter;

    constructor () internal {
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IBToken {
    function getPricePerFullShare() external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address spender, uint256 amount) external returns (bool);
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _shares) external;
}

interface ISwap {
    function coins(int128 i) external view returns (address);
    function underlying_coins(int128 arg0) external view returns (address);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface IBEP20 {
    function balanceOf(address) external view returns (uint);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract BeltSwapRouterV1 is ReentrancyGuard {
    using SafeMath for uint256;

    int128 constant N_COINS = 4;
    uint256 constant PRECISION = 1e18;
    address public swap;

    constructor(address _swap) public {
        swap = _swap;

        ISwap beltSwap = ISwap(_swap);

        for (int128 i = 0; i < N_COINS; i++) {
            address bToken = beltSwap.coins(i);

            IBToken(bToken).approve(_swap, uint256(-1));
            IBEP20(beltSwap.underlying_coins(i)).approve(bToken, uint256(-1));
        }
    }

    function exchange(int128 inputIdx, int128 outputIdx, uint256 inputAmount, uint256 minReturn) public nonReentrant {
        ISwap beltSwap = ISwap(swap);

        IBEP20 tokenA = IBEP20(beltSwap.underlying_coins(inputIdx));
        IBEP20 tokenB = IBEP20(beltSwap.underlying_coins(outputIdx));

        IBToken bTokenA = IBToken(beltSwap.coins(inputIdx));
        IBToken bTokenB = IBToken(beltSwap.coins(outputIdx));

        require(tokenA.transferFrom(msg.sender, address(this), inputAmount), "require:insufficient_input_amount");

        bTokenA.deposit(inputAmount);

        beltSwap.exchange(inputIdx, outputIdx, bTokenA.balanceOf(address(this)), minReturn.mul(1e18).div(bTokenB.getPricePerFullShare()));

        bTokenB.withdraw(bTokenB.balanceOf(address(this)));

        require(tokenB.transfer(msg.sender, tokenB.balanceOf(address(this))), "require:insufficient_output_amount");
    }
}