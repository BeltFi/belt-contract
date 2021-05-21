pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyFildaStorage is Strategy {
    bool public isWHT = false;
    address public wantAddress;
    address public fTokenAddress;
    address[] public fildaMarkets;
    address public mdexRouterAddress;

    address public whtAddress =
    0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;
    address public fildaAddress =
    0xE36FFD17B2661EB57144cEaEf942D95295E637F0;
    address public fildaDistributionAddress =
    0xb74633f2022452f377403B638167b0A135DB096d;

    address public BELTAddress;

    address[] public fildaToWantPath;
    address[] public fildaToBELTPath;

    uint256 public borrowRate = 550;

    address public htHelper;

    address public leverageAdmin;
}
