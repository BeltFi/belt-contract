pragma solidity 0.6.12;

// BUSD
// 0xe9e7cea3dedca5984780bafc599bd69add087d56
// USDC
// 0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d
// USDT
// 0x55d398326f99059ff775485246999027b3197955

// 3eps
// 0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452


interface StableSwap {

    // [BUSD, USDC, USDT] 
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;
    
    // [BUSD, USDC, USDT]
    // function remove_liquidity(uint256 _amount, uint256[3] memory min_amount) external;

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;

    function calc_token_amount(uint256[3] memory amounts, bool deposit) external view returns (uint256);
}

interface LpTokenStaker {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 pid, uint256 _amount) external;
    
    // struct UserInfo {
    //     uint256 amount;
    //     uint256 rewardDebt;
    // }
    // mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);
}

interface FeeDistribution {
    function exit() external;
}

