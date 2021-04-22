pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyAlpacaStorage is Strategy {

    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant alpacaAddress =
    0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F;
    address public constant fairLaunchAddress =
    0xA625AB01B08ce023B2a342Dbb12a16f2C8489A8F;

    bool public isWbnb;

    address public vaultAddress;
    address public wantAddress;
    address public BELTAddress;

    // only updated when deposit / withdraw / earn is called
    uint256 public balanceSnapshot;

    // 1 = WBNB, 3 = BUSD
    uint256 public poolId;

    address[] public alpacaToWantPath;
    address[] public alpacaToBELTPath;
    address[] public wantToBELTPath;

    address public bnbHelper;
}
