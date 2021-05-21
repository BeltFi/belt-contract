pragma solidity 0.6.12;

import "./StrategyLendHubStorage.sol";
import "../../defi/lendHub.sol";
import "../../defi/mdex.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyLendHub is StrategyLendHubStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _lTokenAddress,
        address _mdexRouterAddress,
        address[] memory _lhbToWantPath,
        address[] memory _lhbToBELTPath,
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

        lhbToWantPath = _lhbToWantPath;
        lhbToBELTPath = _lhbToBELTPath;

        lTokenAddress = _lTokenAddress;
        lendHubMarkets = [lTokenAddress];
        mdexRouterAddress = _mdexRouterAddress;

        withdrawFeeNumer = 0;
        withdrawFeeDenom = 10000;

        IERC20(lhbAddress).safeApprove(mdexRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(mdexRouterAddress, uint256(-1));
        if (!isWHT) {
            IERC20(wantAddress).safeApprove(lTokenAddress, uint256(-1));
        }

        ILendHubDistribution(lendHubDistributionAddress).enterMarkets(lendHubMarkets);
    }
    
    receive() override external payable {}
}
