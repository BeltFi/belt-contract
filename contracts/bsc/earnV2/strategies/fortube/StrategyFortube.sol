pragma solidity 0.6.12;

import "./StrategyFortubeStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract StrategyFortube is StrategyFortubeStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _fTokenAddress,
        address _uniRouterAddress,
        address[] memory _forToWantPath,
        address[] memory _forToBELTPath,
        address _logic,
        address admin_,
        bytes memory _data
    ) public TransparentUpgradeableProxy(_logic, admin_, _data) {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;
        wantAddress = _wantAddress;

        if (wantAddress == wbnbAddress) {
            isWBNB = true;
        }

        forToWantPath = _forToWantPath;
        forToBELTPath = _forToBELTPath;


        fTokenAddress = _fTokenAddress;
        fortubeMarkets = [fTokenAddress];
        uniRouterAddress = _uniRouterAddress;

        borrowDepth = 0;        

        withdrawFeeNumer = 5;
        withdrawFeeDenom = 10000;

        IERC20(forAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(bankControllerAddress, uint256(-1));
    }
}
