pragma solidity 0.6.12;

import "./StrategyFildaStorage.sol";
import "../../defi/filda.sol";
import "../../defi/mdex.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyFilda is StrategyFildaStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _fTokenAddress,
        address _mdexRouterAddress,
        address[] memory _fildaToWantPath,
        address[] memory _fildaToBELTPath,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;
        wantAddress = _wantAddress;

        if (wantAddress == whtAddress) {
            isWHT = true;
        }

        fildaToWantPath = _fildaToWantPath;
        fildaToBELTPath = _fildaToBELTPath;

        fTokenAddress = _fTokenAddress;
        fildaMarkets = [fTokenAddress];
        mdexRouterAddress = _mdexRouterAddress;

        withdrawFeeNumer = 0;
        withdrawFeeDenom = 10000;

        IERC20(fildaAddress).safeApprove(mdexRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(mdexRouterAddress, uint256(-1));
        if (!isWHT) {
            IERC20(wantAddress).safeApprove(fTokenAddress, uint256(-1));
        }

        IFildaDistribution(fildaDistributionAddress).enterMarkets(fildaMarkets);
    }
    
    receive() override external payable {}
}
