pragma solidity 0.6.12;

import "./StrategyChannelsStorage.sol";
import "../../defi/channels.sol";
import "../../defi/mdex.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyChannels is StrategyChannelsStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _cTokenAddress,
        address _mdexRouterAddress,
        address[] memory _canToWantPath,
        address[] memory _canToBELTPath,
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

        canToWantPath = _canToWantPath;
        canToBELTPath = _canToBELTPath;

        cTokenAddress = _cTokenAddress;
        channelsMarkets = [cTokenAddress];
        mdexRouterAddress = _mdexRouterAddress;

        withdrawFeeNumer = 0;
        withdrawFeeDenom = 10000;

        IERC20(canAddress).safeApprove(mdexRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(mdexRouterAddress, uint256(-1));
        if (!isWHT) {
            IERC20(wantAddress).safeApprove(cTokenAddress, uint256(-1));
        }

        IChannelsDistribution(channelsDistributionAddress).enterMarkets(channelsMarkets);
    }
    
    receive() override external payable {}
}
