pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IMasterBelt {
    function userInfo(uint, address) external view returns (uint, uint);
    function poolLength() external view returns (uint);
    function poolInfo(uint) external view returns (address, uint, uint, uint, address);
    function pendingBELT(uint256 _pid, address _user) external view returns (uint256);
}

interface IBeltPool {
    function sharesTotal() external view returns (uint);
    function wantLockedTotal() external view returns (uint);
}

interface IDepositor {
    function underlying_coins(int128 arg0) external view returns (address);
    function beltLP() external view returns (address);
    function token() external view returns (address);
}

interface ISwap {
    function balances(int128 i) external view returns (uint256);
}

interface IBEP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function balanceOf(address) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
}

contract BeltSwapView {
    address public masterBelt;
    address public depositor;

    struct FarmingInfo {
        address vault;
        address token;
        uint256 allowance;
        uint256 deposit;
        uint256 balance;
        uint256 reward;
    }

    struct SwapInfo {
        address user;
        uint256 balance;
        uint256 allowance;
        address[] coins;
        uint256[] reserves;
        uint256[] allowances;
        uint256[] balances;
    }

    constructor(address _masterBelt, address _depositor) public {
        masterBelt = _masterBelt;
        depositor = _depositor;
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


    function getSwapStat(address user) public view returns(SwapInfo memory info){
        IDepositor _depositor = IDepositor(depositor);
        ISwap swap = ISwap(_depositor.beltLP());
        IBEP20 LP = IBEP20(_depositor.token());

        address[] memory coins = new address[](4);
        uint256[] memory reserves = new uint256[](4);
        uint256[] memory balances = new uint256[](4);
        uint256[] memory allowances = new uint256[](4);

        for(int128 i = 0; i < 4; i++){
            address coin = _depositor.underlying_coins(i);
            uint256 ui = uint256(i);

            if (user == address(0)) {
                balances[ui] = 0;
                allowances[ui] = 0;
            } else {
                balances[ui] = IBEP20(coin).balanceOf(user);
                allowances[ui] = IBEP20(coin).allowance(user, depositor);
            }

            coins[ui] = coin;
            reserves[ui] = swap.balances(i);
        }

        uint256 userBalance = 0;
        uint256 userAllowance = 0;

        if (user != address(0)) {
            userBalance = LP.balanceOf(user);
            userAllowance = LP.allowance(user, depositor);
        }

        return SwapInfo(user, userBalance, userAllowance, coins, reserves, allowances, balances);
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
                IBEP20(token).allowance(user, masterBelt),
                shares == 0 ? 0 : safeDiv(safeMul(shares, IBeltPool(pool).wantLockedTotal()), IBeltPool(pool).sharesTotal()),
                IBEP20(token).balanceOf(user),
                belt.pendingBELT(i, user)
            );
        }
    }
}