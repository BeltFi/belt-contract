pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyEllipsisStorage is Strategy {
    address public wantAddress;
    address public pancakeRouterAddress;
    
    // BUSD
    address public constant busdAddress = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    // USDC
    address public constant usdcAddress = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    // USDT
    address public constant usdtAddress = 0x55d398326f99059fF775485246999027B3197955;

    // BUSD <-> USDC <-> USDT
    address public constant eps3Address = 0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452;

    // EPS
    address public constant epsAddress =
    0xA7f552078dcC247C2684336020c03648500C6d9F;

    address public constant ellipsisSwapAddress =
    0x160CAed03795365F3A589f10C379FfA7d75d4E76;
    
    address public constant ellipsisStakeAddress =
    0xcce949De564fE60e7f96C85e55177F8B9E4CF61b;
    
    address public constant ellipsisDistibAddress =
    0x4076CC26EFeE47825917D0feC3A79d0bB9a6bB5c;

    uint256 public poolId;

    uint256 public safetyCoeffNumer = 10;
    uint256 public safetyCoeffDenom = 1;

    address public BELTAddress;

    address[] public EPSToWantPath;
    address[] public EPSToBELTPath;
}