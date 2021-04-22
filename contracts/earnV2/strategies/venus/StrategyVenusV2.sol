pragma solidity 0.6.12;

import "./StrategyVenusV2Storage.sol";
import "../../defi/venus.sol";
import "../../defi/pancake.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";


contract StrategyVenusV2 is StrategyVenusV2Storage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _vTokenAddress,
        address _uniRouterAddress,

        address[] memory _venusToWantPath,
        address[] memory _venusToBELTPath,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;
        wantAddress = _wantAddress;

        if (wantAddress == wbnbAddress) {
            wantIsWBNB = true;
        }

        venusToWantPath = _venusToWantPath;
        venusToBELTPath = _venusToBELTPath;

        vTokenAddress = _vTokenAddress;
        venusMarkets = [vTokenAddress];
        uniRouterAddress = _uniRouterAddress;

        borrowDepth = 0;

        withdrawFeeNumer = 5;
        withdrawFeeDenom = 10000;

        IERC20(venusAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        if (!wantIsWBNB) {
            IERC20(wantAddress).safeApprove(vTokenAddress, uint256(-1));
        }

        IVenusDistribution(venusDistributionAddress).enterMarkets(venusMarkets);
    }
    
    receive() override external payable {}
}