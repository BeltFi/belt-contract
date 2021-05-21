// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyACryptoStorage is Strategy {
    uint256 public harvestFee;

    address public pancakeRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant acsAddress =
    0x4197C6EF3879a08cD51e5560da5064B773aa1d29;
    address public constant acsFarmAddress =
    0xb1fa5d3c0111d8E9ac43A19ef17b281D5D4b474E;

    address public vaultAddress;
    address public wantAddress;
    address public BELTAddress;

    // only updated when deposit / withdraw / earn is called
    uint256 public balanceSnapshot;

    address[] public ACSToWantPath;
    address[] public ACSToBELTPath;
    address[] public wantToBELTPath;
}
