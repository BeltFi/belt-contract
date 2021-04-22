pragma solidity 0.6.12;

import "./RepaymentStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract Repayment is TransparentUpgradeableProxy, RepaymentStorage {
    using SafeERC20 for IERC20;

    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {}
    
}