pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

abstract contract StrategyV2 is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    address public govAddress;

    uint256 public lastEarnBlock;
    
    uint256 public buyBackRate;
    uint256 public constant buyBackRateMax = 10000;
    uint256 public constant buyBackRateUL = 800;
    // bsc
    address public constant buyBackAddress =
    0x000000000000000000000000000000000000dEaD;

    uint256 public withdrawFeeNumer;
    uint256 public withdrawFeeDenom;

    function __StrategyV2_init(address govAddress_, uint256 withdrawFeeNumer_, uint256 withdrawFeeDenom_) internal initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __StrategyV2_init_unchained(govAddress_, withdrawFeeNumer_, withdrawFeeDenom_);
    }

    function __StrategyV2_init_unchained(address govAddress_, uint256 withdrawFeeNumer_, uint256 withdrawFeeDenom_) internal initializer {
        govAddress = govAddress_;
        withdrawFeeNumer = withdrawFeeNumer_;
        withdrawFeeDenom = withdrawFeeDenom_;
        buyBackRate = 800;
    }
}
