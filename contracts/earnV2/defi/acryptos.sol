// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ACryptoSVault {
    function totalSupply() external view returns (uint256);
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function getPricePerFullShare() external view returns (uint256);
}

interface ACryptoSFarm {
    function userInfo(address, address) external view returns (uint256 amount, uint256 weight, uint256 rewardDebt, uint256 rewardCredit);
    function pendingSushi(address, address) external returns (uint256 pending);
    function deposit(address, uint256) external;  // Staking
    function withdraw(address, uint256) external;  // Unstaking
    function harvest(address) external;
}

interface ACSToken is IERC20 {
}