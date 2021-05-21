pragma solidity 0.6.12;

import "./MultiStrategyTokenStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract MultiStrategyToken is MultiStrategyTokenStorage, TransparentUpgradeableProxy {
    using SafeERC20 for IERC20;
    
    constructor (
        string memory name_,
        string memory symbol_,
        address _token,
        address[] memory _strategies,
        address _logic,
        address admin_,
        bytes memory _data
    ) public ERC20(name_, symbol_) TransparentUpgradeableProxy(_logic, admin_, _data) {
        // AUTOFARM
        // ACRYPTOS
        // ALPHAHOMORA
        // FORTUBE
        // VENUS
        // ELLIPSIS
        // ALPACA        
        ERC20._setupDecimals(
            ERC20(_token).decimals()
        );
        
        govAddress = msg.sender;

        token = _token;

        strategies = _strategies;
        
        uint256 i;
        for (i = 0; i < strategies.length; i += 1) {
            ratios[strategies[i]] = 1;
            ratioTotal = ratioTotal.add(ratios[strategies[i]]);
        }

        for (i = 0; i < strategies.length; i += 1) {
            depositActive[strategies[i]] = true;
            withdrawActive[strategies[i]] = true;
        }
        depositActiveCount = strategies.length;        
        withdrawActiveCount = strategies.length;


        entranceFeeNumer = 0;
        entranceFeeDenom = 1;

        rebalanceThresholdNumer = 10;
        rebalanceThresholdDenom = 100;

        isWbnb = token == wbnbAddress;
    
        approveToken();
    }

    function approveToken() public {
        uint i = 0;
        for (; i < strategies.length; i += 1) {
            IERC20(token).safeApprove(strategies[i], uint(-1));
        }
    }
}
