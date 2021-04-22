pragma solidity 0.6.12;

import "../Strategy.sol";

abstract contract StrategyAutoStorage is Strategy {
    address public wantAddress;

    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant autoAddress =
    0xa184088a740c695E156F91f5cC086a06bb78b827;
    address public constant autoFarmAddress =
    0x0895196562C7868C5Be92459FaE7f877ED450452;
    
    // only updated when deposit / withdraw / earn is called
    uint256 public balanceSnapshot;

    //wbnb 84, busd 85, usdt 86, usdc 87, btcb 89, eth 90
    uint256 public poolId;

    address public BELTAddress;

    address[] public autoToWantPath;
    address[] public autoToBELTPath;
    address[] public wantToBELTPath;
}
