pragma solidity 0.6.12;

import "../Strategy.sol";


abstract contract StrategyVenusV2Storage is Strategy {
    bool public wantIsWBNB = false;
    address public wantAddress;
    address public vTokenAddress;
    address[] public venusMarkets;
    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant venusAddress =
    0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    address public constant earnedAddress = venusAddress;
    address public constant venusDistributionAddress =
    0xfD36E2c2a6789Db23113685031d7F16329158384;

    address public BELTAddress;


    address[] public venusToWantPath;
    address[] public venusToBELTPath;

    uint256 public borrowRate = 585;
    uint256 public borrowDepth = 0;
    uint256 public constant BORROW_RATE_MAX = 595;
    uint256 public constant BORROW_RATE_MAX_HARD = 599;
    uint256 public constant BORROW_DEPTH_MAX = 6;

    uint256 public supplyBal = 0;
    uint256 public borrowBal = 0;
    uint256 public supplyBalTargeted = 0;
    uint256 public supplyBalMin = 0;

    address public bnbHelper;
}
