pragma solidity 0.6.12;

import "./StrategyToken.sol";

abstract contract MultiStrategyTokenStorage is StrategyToken {
    address public constant wbnbAddress =
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    bool public isWbnb;

    address[] public strategies;

    mapping(address => uint256) public ratios;

    mapping (address => bool) public depositActive;
    
    mapping (address => bool) public withdrawActive;
    
    uint256 public depositActiveCount;
    
    uint256 public withdrawActiveCount;

    uint256 public ratioTotal;

    uint256 public rebalanceThresholdNumer;

    uint256 public rebalanceThresholdDenom;

    address public bnbHelper;

    address public policyAdmin;
}
