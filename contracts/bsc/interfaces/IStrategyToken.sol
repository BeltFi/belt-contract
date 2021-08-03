pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IStrategyToken is IERC20 {    
    function balance() external view returns (uint256);
    function balanceStrategy() external view returns (uint256);
    function calcPoolValueInToken() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function sharesToAmount(uint256 _shares) external view returns (uint256);
    function amountToShares(uint256 _amount) external view returns (uint256);
    function isWbnb() external view returns (bool);
    function token() external view returns (address);
    function govAddress() external view returns (address);
    function entranceFeeNumer() external view returns (uint256);
    function entranceFeeDenom() external view returns (uint256);
    function depositPaused() external view returns (bool);
    function withdrawPaused() external view returns (bool);

    
    function deposit(uint256 _amount, uint256 _minShares) external;
    function withdraw(uint256 _shares, uint256 _minAmount) external;

    function setGovAddress(address _govAddress) external;
    function pauseDeposit() external;
    function unpauseDeposit() external;
    function pauseWithdraw() external;
    function unpauseWithdraw() external;
}


interface ISingleStrategyToken is IStrategyToken {
    function strategy() external view returns (address);

    function supplyStrategy() external;
    function updateStrategy() external;
    function setEntranceFee(uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) external;
}

interface ISingleStrategyToken2 is IStrategyToken {
    function strategy() external view returns (address);

    function updateStrategy() external;
}

interface IMultiStrategyToken is IStrategyToken {
    function strategies(uint256 idx) external view returns (address);
    function depositActiveCount() external view returns (uint256);
    function withdrawActiveCount() external view returns (uint256);
    function strategyCount() external view returns (uint256);
    function ratios(address _strategy) external view returns (uint256);
    function depositActive(address _strategy) external view returns (bool);
    function withdrawActive(address _strategy) external view returns (bool);
    function ratioTotal() external view returns (uint256);
    function findMostOverLockedStrategy(uint256 withdrawAmt) external view returns (address, uint256);
    function findMostLockedStrategy() external view returns (address, uint256);
    function findMostInsufficientStrategy() external view returns (address, uint256);
    function getBalanceOfOneStrategy(address strategyAddress) external view returns (uint256 bal);

    // doesn"t guarantee that withdrawing shares returned by this function will always be successful.
    function getMaxWithdrawableShares() external view returns (uint256);

    
    function setPolicyAdmin(address _policyAdmin) external;
    function rebalance() external;
    function changeRatio(uint256 index, uint256 value) external;
    function setStrategyActive(uint256 index, bool isDeposit, bool b) external;
    function setRebalanceThreshold(uint256 _rebalanceThresholdNumer, uint256 _rebalanceThresholdDenom) external;
    function inCaseTokensGetStuck(address _token, uint256 _amount, address _to) external;
    function updateAllStrategies() external;
}
