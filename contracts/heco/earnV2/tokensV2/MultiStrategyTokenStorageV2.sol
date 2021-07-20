pragma solidity 0.6.12;

contract MultiStrategyTokenStorageV2 {

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
