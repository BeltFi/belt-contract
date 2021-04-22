// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StrategyACryptoStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyACrypto is StrategyACryptoStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _vaultAddress,
        address _BELTAddress,
        address _wantAddress,
        address _pancakeRouterAddress,
        address[] memory _ACSToWantPath,
        address[] memory _ACSToBELTPath,
        address[] memory _wantToBETLPATH,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {
        harvestFee = 10 * 10 ** 18;

        govAddress = msg.sender;
        vaultAddress = _vaultAddress;
        BELTAddress = _BELTAddress;

        wantAddress = _wantAddress;

        ACSToWantPath = _ACSToWantPath;
        ACSToBELTPath = _ACSToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        pancakeRouterAddress = _pancakeRouterAddress;

        withdrawFeeNumer = 1;
        withdrawFeeDenom = 10000;

        IERC20(acsAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(vaultAddress, uint256(-1));
        IERC20(vaultAddress).safeApprove(acsFarmAddress, uint256(-1));
    }
}
