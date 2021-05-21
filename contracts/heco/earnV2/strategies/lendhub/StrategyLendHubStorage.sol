pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyLendHubStorage is Strategy {
    bool public isWHT = false;
    address public wantAddress;
    address public lTokenAddress;
    address[] public lendHubMarkets;
    address public mdexRouterAddress;

    address public whtAddress =
    0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;
    address public lhbAddress =
    0x8F67854497218043E1f72908FFE38D0Ed7F24721;
    address public lendHubDistributionAddress =
    0x6537d6307ca40231939985BCF7D83096Dd1B4C09;

    address public BELTAddress;

    address[] public lhbToWantPath;
    address[] public lhbToBELTPath;

    uint256 public borrowRate = 550;

    address public htHelper;

    address public leverageAdmin;
}
