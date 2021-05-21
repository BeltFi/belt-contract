pragma solidity 0.6.12;

import "./StrategyEllipsisStorage.sol";
import "../../defi/ellipsis.sol";
import "../../defi/pancake.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyEllipsis is StrategyEllipsisStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _pancakeRouterAddress,
        uint256 _poolId,
        address[] memory _EPSToWantPath,
        address[] memory _EPSToBELTPath,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {

        govAddress = msg.sender;
        BELTAddress = _BELTAddress;

        wantAddress = _wantAddress;

        poolId = _poolId;

        EPSToWantPath = _EPSToWantPath;
        EPSToBELTPath = _EPSToBELTPath;

        pancakeRouterAddress = _pancakeRouterAddress;

        withdrawFeeNumer = 1;
        withdrawFeeDenom = 10000;

        IERC20(epsAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(busdAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdcAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(usdtAddress).safeApprove(ellipsisSwapAddress, uint256(-1));
        IERC20(eps3Address).safeApprove(ellipsisStakeAddress, uint256(-1));
    }
}