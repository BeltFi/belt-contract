pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IMasterBelt {
    function userInfo(uint, address) external view returns (uint, uint);
    function poolLength() external view returns (uint);
    function poolInfo(uint) external view returns (address, uint, uint, uint, address);
    function pendingBELT(uint256 _pid, address _user) external view returns (uint256);
}

interface IBToken {
    function calcPoolValueInToken() external view returns (uint);
    function totalSupply() external view returns (uint256);
}

interface IBeltPool {
    function sharesTotal() external view returns (uint);
    function wantLockedTotal() external view returns (uint);
}

interface IDepositor {
    function coins(int128 arg0) external view returns (address);
    function underlying_coins(int128 arg0) external view returns (address);
    function beltLP() external view returns (address);
    function token() external view returns (address);
}

interface ISwap {
    function fee() external view returns (uint256);
    function buyback_fee() external view returns (uint256);
    function coins(int128 i) external view returns (address);
    function balances(int128 i) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
    function A() external view returns (uint256);
}

interface IBEP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function balanceOf(address) external view returns (uint);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function totalSupply() external view returns (uint256);
}

contract BeltSwapView is Ownable {
    address public masterBelt;
    mapping(address => uint) public depositorInfo;

    struct SwapInfo {
        address user;
        address lpToken;
        uint256 lpTotalSupply;
        uint256 balance;
        uint256 allowance;
        uint256 allowanceSwap;
        uint256 virtualPrice;
        uint256 A;
        uint256 buyback_fee;
        uint256 fee;
        address[] coins;
        uint256[] totalSupplies;
        uint256[] volumes;
        uint256[] reserves;
        uint256[] depositAllowances;
        uint256[] swapAllowances;
        uint256[] balances;
    }

    struct FarmingInfo {
        address vault;
        address token;
        uint256 pid;
        uint256 allowance;
        uint256 deposit;
        uint256 balance;
        uint256 reward;
        uint256 totalLocked;
    }

    constructor(address _masterBelt, address[] memory _depositors, uint[] memory _count) public {
        masterBelt = _masterBelt;

        for(uint i =0;i < _depositors.length; i++ ){
            depositorInfo[_depositors[i]] = _count[i];
        }
    }

    function version() public pure returns (string memory) {
        return "v1";
    }

    function safeMul(uint a, uint b) internal pure returns (uint) {
        require(a == 0 || b <= uint(-1) / a);

        return a * b;
    }

    function safeSub(uint a, uint b) internal pure returns (uint) {
        require(b <= a);

        return a - b;
    }

    function safeAdd(uint a, uint b) internal pure returns (uint) {
        require(b <= uint(-1) - a);

        return a + b;
    }

    function safeDiv(uint a, uint b) internal pure returns (uint) {
        require(b != 0);

        return a / b;
    }

    function addSwap(address _depositor, uint256 coinsLength) public onlyOwner {
        require(depositorInfo[_depositor] == 0);

        depositorInfo[_depositor] = coinsLength;
    }

    function getSwapStat(address user,address depositor) public view returns(SwapInfo memory){
        address[] memory coins = new address[](depositorInfo[depositor]);
        uint256[] memory volumes = new uint256[](depositorInfo[depositor]);
        uint256[] memory reserves = new uint256[](depositorInfo[depositor]);
        uint256[] memory balances = new uint256[](depositorInfo[depositor]);
        uint256[] memory allowances = new uint256[](depositorInfo[depositor]);
        uint256[] memory allowancesSwap = new uint256[](depositorInfo[depositor]);
        uint256[] memory totalSupplies = new uint256[](depositorInfo[depositor]);

        for(int128 i = 0; i < int128(depositorInfo[depositor]); i++){
            address coin = IDepositor(depositor).underlying_coins(i);
            // uint256 ui = uint256(i);

            if (user == address(0)) {
                balances[uint256(i)] = 0;
                allowances[uint256(i)] = 0;
                allowancesSwap[uint256(i)] = 0;
            } else {
                balances[uint256(i)] = IBEP20(coin).balanceOf(user);
                allowances[uint256(i)] = IBEP20(coin).allowance(user, depositor);
                allowancesSwap[uint256(i)] = IBEP20(coin).allowance(user, IDepositor(depositor).beltLP());
            }

            totalSupplies[uint256(i)] = IBToken(IDepositor(depositor).coins(i)).totalSupply();
            volumes[uint256(i)] = IBToken(IDepositor(depositor).coins(i)).calcPoolValueInToken();
            coins[uint256(i)] = coin;
            reserves[uint256(i)] = ISwap(IDepositor(depositor).beltLP()).balances(i);
        }

        uint256 userBalance = 0;
        uint256 userAllowance = 0;

        if (user != address(0)) {
            userBalance = IBEP20(IDepositor(depositor).token()).balanceOf(user);
            userAllowance = IBEP20(IDepositor(depositor).token()).allowance(user, masterBelt);
        }

        return SwapInfo(user, address(IDepositor(depositor).token()), IBEP20(IDepositor(depositor).token()).totalSupply(), userBalance, userAllowance, IBEP20(IDepositor(depositor).token()).allowance(user, depositor), ISwap(IDepositor(depositor).beltLP()).get_virtual_price(), ISwap(IDepositor(depositor).beltLP()).A(), ISwap(IDepositor(depositor).beltLP()).buyback_fee(), ISwap(IDepositor(depositor).beltLP()).fee(), coins, totalSupplies, volumes, reserves, allowances, allowancesSwap, balances);
    }


    function getUserBeltStat(address user) public view returns(FarmingInfo[] memory info){
        IMasterBelt belt = IMasterBelt(masterBelt);
        uint poolLength = belt.poolLength();

        info = new FarmingInfo[](poolLength);

        for(uint i = 0; i < poolLength; i++){
            (uint shares,) = belt.userInfo(i, user);

            (address token, , , , address pool) = belt.poolInfo(i);

            info[i] = FarmingInfo(
                pool,
                token,
                i,
                IBEP20(token).allowance(user, masterBelt),
                shares == 0 ? 0 : safeDiv(safeMul(shares, IBeltPool(pool).wantLockedTotal()), IBeltPool(pool).sharesTotal()),
                IBEP20(token).balanceOf(user),
                belt.pendingBELT(i, user),
                IBeltPool(pool).wantLockedTotal()
            );
        }
    }
}