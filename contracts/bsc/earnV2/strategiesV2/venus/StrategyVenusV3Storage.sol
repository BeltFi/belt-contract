pragma solidity 0.6.12;

contract StrategyVenusV3Storage {
    bool public isWBNB;
    address public wantAddress;
    address public vTokenAddress;
    address[] public venusMarkets;
    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant xvsAddress =
    0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
    address public constant earnedAddress = xvsAddress;
    address public constant venusDistributionAddress =
    0xfD36E2c2a6789Db23113685031d7F16329158384;

    address public BELTAddress;

    address[] public venusToWantPath;
    address[] public venusToBELTPath;

    uint256 public borrowRate;

    address public bnbHelper;

    address public leverageAdmin;
    
    uint256 public buyBackPoolRate;
    address public buyBackPoolAddress;
}