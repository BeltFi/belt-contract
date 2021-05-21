pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyChannelsStorage is Strategy {
    bool public isWHT = false;
    address public wantAddress;
    address public cTokenAddress;
    address[] public channelsMarkets;
    address public mdexRouterAddress;

    address public whtAddress =
    0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;
    address public canAddress =
    0x1e6395E6B059fc97a4ddA925b6c5ebf19E05c69f;
    address public channelsDistributionAddress =
    0x8955aeC67f06875Ee98d69e6fe5BDEA7B60e9770;

    address public BELTAddress;

    address[] public canToWantPath;
    address[] public canToBELTPath;

    uint256 public borrowRate = 550;

    address public htHelper;

    address public leverageAdmin;
}
