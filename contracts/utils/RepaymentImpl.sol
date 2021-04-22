pragma solidity 0.6.12;

import "./RepaymentStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract RepaymentImpl is RepaymentStorage {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
}