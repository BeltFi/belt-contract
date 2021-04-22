// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyAlphaStorage is Strategy {

    address public pancakeRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant alphaAddress =
    0xa1faa113cbE53436Df28FF0aEe54275c13B40975;
    
    //ibBNB
    address public constant bankAddress =
    0x3bB5f6285c312fc7E1877244103036ebBEda193d;
    address public constant distributor = 
    0x86FC56Eb6E7eF9439b89Dd5825F08A14460D46A1;

    address public wantAddress;
    address public BELTAddress;

    // only updated when deposit / withdraw / earn is called
    uint256 public balanceSnapshot;

    address[] public ALPHAToWantPath;
    address[] public ALPHAToBELTPath;
    address[] public wantToBELTPath;
    // cake to BELT

    address public bnbHelper;
}
