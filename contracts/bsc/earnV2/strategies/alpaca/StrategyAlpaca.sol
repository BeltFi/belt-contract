pragma solidity 0.6.12;

import "./StrategyAlpacaStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyAlpaca is StrategyAlpacaStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _vaultAddress,
        address _BELTAddress,
        address _wantAddress,
        address _uniRouterAddress,
        uint256 _poolId,
        address[] memory _alpacaToWantPath,
        address[] memory _alpacaToBELTPath,
        address[] memory _wantToBETLPATH,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {
        govAddress = msg.sender;

        vaultAddress = _vaultAddress;
        wantAddress = _wantAddress;
        BELTAddress = _BELTAddress;

        poolId = _poolId;
        isWbnb = _wantAddress == wbnbAddress;

        alpacaToWantPath = _alpacaToWantPath;
        alpacaToBELTPath = _alpacaToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        uniRouterAddress = _uniRouterAddress;

        IERC20(alpacaAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(vaultAddress, uint256(-1));
        IERC20(vaultAddress).safeApprove(fairLaunchAddress, uint256(-1));
    }
}
