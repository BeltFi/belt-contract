pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract StrategyTokenV2 is Initializable, ERC20Upgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    address public token;

    address public govAddress;

    uint256 public entranceFeeNumer;

    uint256 public entranceFeeDenom;

    bool public depositPaused;

    bool public withdrawPaused;
    
    address public constant wbnbAddress =
        0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;

    bool public isWBNB;

    function  __StrategyTokenV2_init(
        string memory name_,
        string memory symbol_,
        address token_,
        address govAddress_,
        uint256 entranceFeeNumer_,
        uint256 entranceFeeDenom_
    ) internal initializer {
        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();
        __Ownable_init();
        __StrategyTokenV2_init_unchained(token_, govAddress_, entranceFeeNumer_, entranceFeeDenom_);
    }

    function  __StrategyTokenV2_init_unchained(
        address token_,
        address govAddress_,
        uint256 entranceFeeNumer_,
        uint256 entranceFeeDenom_
    ) internal initializer {
        token = token_;

        isWBNB = token == wbnbAddress;

        govAddress = govAddress_;
        
        ERC20Upgradeable._setupDecimals(
            ERC20(token_).decimals()
        );

        entranceFeeNumer = entranceFeeNumer_;
        entranceFeeDenom = entranceFeeDenom_;
        depositPaused = false;
        withdrawPaused = false;
    }
}
