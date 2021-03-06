pragma solidity 0.6.12;

import "./SingleStrategyTokenStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract SingleStrategyToken is SingleStrategyTokenStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor (
        string memory name_,
        string memory symbol_,
        address _token,
        address _strategy,
        address _logic,
        address admin_,
        bytes memory _data
    ) public ERC20(name_, symbol_) TransparentUpgradeableProxy(_logic, admin_, _data) {
        token = _token;
        strategy = _strategy;
        govAddress = msg.sender;
        entranceFeeNumer = 1;
        entranceFeeDenom = 1000;

        isWbnb = token == wbnbAddress;

        approveToken();
    }

    function approveToken() public {
        IERC20(token).safeApprove(strategy, uint(-1));
    }
}
