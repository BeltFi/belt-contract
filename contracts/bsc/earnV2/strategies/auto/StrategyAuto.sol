pragma solidity 0.6.12;

import "./StrategyAutoStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyAuto is StrategyAutoStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _uniRouterAddress,
        uint256 _poolId,
        address[] memory _autoToWantPath,
        address[] memory _autoToBELTPath,
        address[] memory _wantToBETLPATH,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;

        wantAddress = _wantAddress;

        poolId = _poolId;

        autoToWantPath = _autoToWantPath;
        autoToBELTPath = _autoToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        uniRouterAddress = _uniRouterAddress;

        withdrawFeeNumer = 1;
        withdrawFeeDenom = 10000;

        IERC20(autoAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(autoFarmAddress, uint256(-1));
    }
}
