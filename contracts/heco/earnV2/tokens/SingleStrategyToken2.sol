pragma solidity 0.6.12;

import "./SingleStrategyTokenStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract SingleStrategyToken2 is SingleStrategyTokenStorage, TransparentUpgradeableProxy {
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
        entranceFeeNumer = 0;
        entranceFeeDenom = 1;

        ERC20._setupDecimals(
            ERC20(_token).decimals()
        );

        isWbnb = token == wbnbAddress;

        approveToken();
    }

    function approveToken() public {
        IERC20(token).safeApprove(strategy, uint(-1));
    }
}
