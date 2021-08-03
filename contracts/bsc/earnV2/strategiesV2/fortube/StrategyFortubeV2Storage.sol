pragma solidity 0.6.12;

contract StrategyFortubeV2Storage {
    bool public isWBNB;
    address public wantAddress;
    address public fTokenAddress;
    address[] public fortubeMarkets;
    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant forAddress  =
    0x658A109C5900BC6d2357c87549B651670E5b0539;
    address public constant earnedAddress = forAddress;
    address public constant forDistributionAddress =
    0x55838F18e79cFd3EA22Eea08Bd3Ec18d67f314ed;
    address public constant bankAddress =
    0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672;
    address public constant bankControllerAddress =
    0xc78248D676DeBB4597e88071D3d889eCA70E5469;

    address public BELTAddress;

    address[] public forToWantPath;
    address[] public forToBELTPath;

    uint256 public borrowRate;

    address public bnbHelper;

    address public leverageAdmin;
}
