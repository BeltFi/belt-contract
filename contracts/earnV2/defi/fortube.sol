pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// live fortube IBANK
// 0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672
// live fortube Controller
// 0xc78248D676DeBB4597e88071D3d889eCA70E5469


interface IBank {
    function deposit(address token, uint256 amount) external payable;
    function withdraw(address underlying, uint256 withdrawTokens) external;
    function withdrawUnderlying(address underlying, uint256 withdrawAmount) external;
    function borrow(address underlying, uint256 borrowAmount) external;
    function repay(address token, uint256 repayAmount) external payable;
    function controller() external returns (address);
}

interface IBankController {
     function getAssetsIn(address account)
        external
        view
        returns (address[] memory);

    function getAccountLiquidity(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

        
    function getFTokeAddress(address underlying)
        external
        view
        returns (address);

    function isFTokenValid(address fToken) external view returns (bool);
}

interface IMiningReward {
    function rewardToken() external view returns(address);

    function claimReward() external;

    function checkBalance(address account) external view returns (uint256);
}

interface IFToken is IERC20 {
    function balanceOfUnderlying(address owner) external returns (uint256);
    
    function calcBalanceOfUnderlying(address owner)
        external
        view
        returns (uint256);
    
    
    function borrowBalanceCurrent(address account) external returns (uint256);
}
