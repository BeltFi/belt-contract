// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StrategyAlphaStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyAlpha is StrategyAlphaStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _pancakeRouterAddress,
        address[] memory _ALPHAToWantPath,
        address[] memory _ALPHAToBELTPath,
        address[] memory _wantToBETLPATH,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;

        wantAddress = wbnbAddress;

        ALPHAToWantPath = _ALPHAToWantPath;
        ALPHAToBELTPath = _ALPHAToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        pancakeRouterAddress = _pancakeRouterAddress;

        IERC20(alphaAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
    }
}
