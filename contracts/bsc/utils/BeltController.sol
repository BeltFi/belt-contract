pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "../interfaces/IStrategy.sol";
import "../interfaces/IStrategyToken.sol";

contract BeltControllerStorage {
    EnumerableSetUpgradeable.AddressSet internal singleStrategyTokens;
    EnumerableSetUpgradeable.AddressSet internal singleStrategyToken2s;
    EnumerableSetUpgradeable.AddressSet internal multiStrategyTokens;
    EnumerableSetUpgradeable.AddressSet internal strategies;

    EnumerableSetUpgradeable.AddressSet internal pauseControllers;
    EnumerableSetUpgradeable.AddressSet internal policyControllers;
}

contract BeltController is Initializable, OwnableUpgradeable, BeltControllerStorage {
    using SafeMathUpgradeable for uint256;

	using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
	using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    
    event MultiStrategyAdded(address addr);
    event MultiStrategyRemoved(address addr);
    event SingleStrategyAdded(address addr);
    event SingleStrategyRemoved(address addr);
    event SingleStrategy2Added(address addr);
    event SingleStrategy2Removed(address addr);
    event StrategyAdded(address addr);
    event StrategyRemoved(address addr);
    event PolicyControllerAdded(address addr);
    event PolicyControllerRemoved(address addr);
    event PauseControllerAdded(address addr);
    event PauseControllerRemoved(address addr);

    event StrategyTokenWithdrawPause(address addr, address account, bool paused);
    event StrategyTokenDepositPause(address addr, address account, bool paused);
    event StrategyPause(address addr, address account, bool paused);

    event StrategyTokenGovAddressSet(address addr, address _govAddress);
    event PolicyAdminSet(address addr, address _policyAdmin);
    event Rebalanced(address addr);
    event RatioChanged(address addr, uint256 index, uint256 value);
    event StrategyActiveSet(address addr, uint256 index, bool isDeposit, bool b);
    event RebalanceThresholdSet(address addr, uint256 _rebalanceThresholdNumer, uint256 _rebalanceThresholdDenom);
    event InCaseTokensGetStuckCalled(address addr, address _token, uint256 _amount, address _to);
    event SingleStrategyEntranceFeeSet(address addr, uint256 _entranceFeeNumer, uint256 _entranceFeeDenom);
    event StrategyGovSet(address addr, address _govAddress);



    modifier onlyStrategyToken(address addr) {
        require(isStrategyToken(addr));
        _;
    }

    modifier onlyMultiStrategyToken(address addr) {
        require(isMultiStrategyToken(addr));
        _;
    }

    modifier onlySingleStrategyToken(address addr) {
        require(isSingleStrategyToken(addr));
        _;
    }

    modifier onlySingleStrategyToken1(address addr) {
        require(isSingleStrategyToken1(addr));
        _;
    }

    modifier onlyStrategy(address addr) {
        require(isStrategy(addr));
        _;
    }

    modifier onlyPolicyController() {
        require(isPolicyController(_msgSender()));
        _;
    }
    
    modifier onlyPauseController() {
        require(isPauseController(_msgSender()));
        _;
    }

    function isStrategyToken(address addr) public view returns (bool) {
        return isMultiStrategyToken(addr) || isSingleStrategyToken(addr);
    }

    function isMultiStrategyToken(address addr) public view returns (bool) {
        return multiStrategyTokens.contains(addr);
    }

    function isSingleStrategyToken(address addr) public view returns (bool) {
        return isSingleStrategyToken1(addr) || isSingleStrategyToken2(addr);
    }

    function isSingleStrategyToken1(address addr) public view returns (bool) {
        return singleStrategyTokens.contains(addr);
    }

    function isSingleStrategyToken2(address addr) public view returns (bool) {
        return singleStrategyToken2s.contains(addr);
    }

    function isStrategy(address addr) public view returns (bool) {
        return strategies.contains(addr);
    }

    function isPolicyController(address addr) public view returns (bool) {
        return policyControllers.contains(addr);
    }

    function isPauseController(address addr) public view returns (bool) {
        return pauseControllers.contains(addr);
    }
    
    function __BeltController_init() public initializer {
        __Ownable_init();
        __BeltController_init_unchained();
    }

    function __BeltController_init_unchained() internal initializer {
        pauseControllers.add(owner());
        policyControllers.add(owner());
    }

    function addMultiStrategy(address addr) external onlyOwner {
        require(addr != address(0));
        require(!isSingleStrategyToken(addr) && !isStrategy(addr));
        require(multiStrategyTokens.add(addr));
        emit MultiStrategyAdded(addr);
    }

    function removeMultiStrategy(address addr) external onlyOwner {
        require(addr != address(0));
        require(multiStrategyTokens.remove(addr));
        emit MultiStrategyRemoved(addr);
    }

    function addSingleStrategy(address addr) external onlyOwner {
        require(addr != address(0));
        require(!isStrategyToken(addr) && !isStrategy(addr));
        require(singleStrategyTokens.add(addr));
        emit SingleStrategyAdded(addr);
    }

    function removeSingleStrategy(address addr) external onlyOwner {
        require(addr != address(0));
        require(singleStrategyTokens.remove(addr));
        emit SingleStrategyRemoved(addr);
    }

    function addSingleStrategy2(address addr) external onlyOwner {
        require(addr != address(0));
        require(!isStrategyToken(addr) && !isStrategy(addr));
        require(singleStrategyToken2s.add(addr));
        emit SingleStrategy2Added(addr);
    }

    function removeSingleStrategy2(address addr) external onlyOwner {
        require(singleStrategyToken2s.remove(addr));
        emit SingleStrategy2Removed(addr);
    }

    function addStrategy(address addr) external onlyOwner {
        require(addr != address(0));
        require(!isStrategyToken(addr));
        require(strategies.add(addr));
        emit StrategyAdded(addr);
    }

    function removeStrategy(address addr) external onlyOwner {
        require(strategies.remove(addr));
        emit StrategyRemoved(addr);
    }

    function addPolicyController(address addr) external onlyOwner {
        require(addr != address(0));
        require(policyControllers.add(addr));
        emit PolicyControllerAdded(addr);
    }

    function removePolicyController(address addr) external onlyOwner {
        require(policyControllers.remove(addr));
        emit PolicyControllerRemoved(addr);
    }

    function addPauseController(address addr) external onlyOwner {
        require(addr != address(0));
        require(pauseControllers.add(addr));
        emit PauseControllerAdded(addr);
    }

    function removePauseController(address addr) external onlyOwner {
        require(pauseControllers.remove(addr));
        emit PauseControllerRemoved(addr);
    }

    // StrategyToken
    // function setGovAddress(address _govAddress) external;
    // function pauseDeposit() external;
    // function unpauseDeposit() external;
    // function pauseWithdraw() external;
    // function unpauseWithdraw() external;
    function setStrategyTokenGovAddress(address addr, address _govAddress) external onlyOwner onlyStrategyToken(addr) {
        require(_govAddress != address(0));
        IStrategyToken(addr).setGovAddress(_govAddress);
        StrategyTokenGovAddressSet(addr, _govAddress);
    }

    function pauseDepositStrategyToken(address addr) public onlyPauseController onlyStrategyToken(addr) {
        if (!IStrategyToken(addr).depositPaused()) {
            IStrategyToken(addr).pauseDeposit();
            emit StrategyTokenDepositPause(addr, msg.sender, true);
        }
    }

    function unpauseDepositStrategyToken(address addr) public onlyPauseController onlyStrategyToken(addr) {
        if (IStrategyToken(addr).depositPaused()) {
            IStrategyToken(addr).unpauseDeposit();
            emit StrategyTokenDepositPause(addr, msg.sender, false);
        }
    }

    function pauseWithdrawStrategyToken(address addr) public onlyPauseController onlyStrategyToken(addr) {
        if (!IStrategyToken(addr).withdrawPaused()) {
            IStrategyToken(addr).pauseWithdraw();
            emit StrategyTokenWithdrawPause(addr, msg.sender, true);
        }
    }

    function unpauseWithdrawStrategyToken(address addr) public onlyPauseController onlyStrategyToken(addr) {
        if (IStrategyToken(addr).withdrawPaused()) {
            IStrategyToken(addr).unpauseWithdraw();
            emit StrategyTokenWithdrawPause(addr, msg.sender, false);
        }
    }

    function pauseStrategyToken(address addr) public onlyPauseController {
        pauseDepositStrategyToken(addr);
        pauseWithdrawStrategyToken(addr);
    }

    function unpauseStrategyToken(address addr) public onlyPauseController {
        unpauseDepositStrategyToken(addr);
        unpauseWithdrawStrategyToken(addr);
    }

    function pauseStrategyTokens(address[] memory tokens) public onlyPauseController {
        uint256 i;
        for (i = 0; i < tokens.length; i += 1) {
            pauseStrategyToken(tokens[i]);
        }
    }

    function unpauseStrategyTokens(address[] memory tokens) public onlyPauseController {
        uint256 i;
        for (i = 0; i < tokens.length; i += 1) {
            unpauseStrategyToken(tokens[i]);
        }
    }

    // multiStrategyGovFunction
    // function setPolicyAdmin(address _policyAdmin) external;
    // function rebalance() external;
    // function changeRatio(uint256 index, uint256 value) external;
    // function setStrategyActive(uint256 index, bool isDeposit, bool b) external;
    // function setRebalanceThreshold(uint256 _rebalanceThresholdNumer, uint256 _rebalanceThresholdDenom) external;
    // function inCaseTokensGetStuck(address _token, uint256 _amount, address _to) external;
    // function updateAllStrategies() external;
    function setPolicyAdmin(address addr, address _policyAdmin) public onlyOwner onlyMultiStrategyToken(addr) {
        IMultiStrategyToken(addr).setPolicyAdmin(_policyAdmin);
        emit PolicyAdminSet(addr, _policyAdmin);
    }

    function rebalance(address addr) public onlyPolicyController onlyMultiStrategyToken(addr) {
        IMultiStrategyToken(addr).rebalance();
        emit Rebalanced(addr);
    }
    
    function changeRatio(address addr, uint256 index, uint256 value) public onlyPolicyController onlyMultiStrategyToken(addr) {
        IMultiStrategyToken(addr).changeRatio(index, value);
        emit RatioChanged(addr, index, value);
    }
    
    function setStrategyActive(address addr, uint256 index, bool isDeposit, bool b) public onlyPolicyController onlyMultiStrategyToken(addr) {
        IMultiStrategyToken(addr).setStrategyActive(index, isDeposit, b);
        emit StrategyActiveSet(addr, index, isDeposit, b);
    }
    
    function setRebalanceThreshold(address addr, uint256 _rebalanceThresholdNumer, uint256 _rebalanceThresholdDenom) public onlyPolicyController onlyMultiStrategyToken(addr) {
        IMultiStrategyToken(addr).setRebalanceThreshold(_rebalanceThresholdNumer, _rebalanceThresholdDenom);
        emit RebalanceThresholdSet(addr, _rebalanceThresholdNumer, _rebalanceThresholdDenom);
    }
    
    function inCaseTokensGetStuck(address addr, address _token, uint256 _amount, address _to) public onlyOwner onlyMultiStrategyToken(addr) {
        IMultiStrategyToken(addr).inCaseTokensGetStuck(_token, _amount, _to);
        emit InCaseTokensGetStuckCalled(addr, _token, _amount, _to);
    }
    
    function updateAllStrategies(address addr) public onlyMultiStrategyToken(addr) {
        IMultiStrategyToken(addr).updateAllStrategies();
    }


    // singleTokenGovFunctions
    // function supplyStrategy() external;
    // function updateStrategy() external;
    // function setEntranceFee(uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) external;
    function singleStrategySupplyStrategy(address addr) public onlySingleStrategyToken1(addr) {
        ISingleStrategyToken(addr).supplyStrategy();
    }

    function singleStrategyUpdateStrategy(address addr) public onlySingleStrategyToken(addr) {
        ISingleStrategyToken(addr).updateStrategy();
    }

    function singleStrategySetEntranceFee(address addr, uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) public onlyOwner onlySingleStrategyToken1(addr) {
        ISingleStrategyToken(addr).setEntranceFee(_entranceFeeNumer, _entranceFeeDenom);
        emit SingleStrategyEntranceFeeSet(addr, _entranceFeeNumer, _entranceFeeDenom);
    }


    // strategyGovFunctions
    // function updateStrategy() external;
    // function pause() external;
    // function unpause() external;
    // function setGov(address _govAddress) external;
    function strategyUpdateStrategy(address addr) public onlyStrategy(addr) {
        IStrategy(addr).updateStrategy();
    }

    function pauseStrategy(address addr) public onlyPauseController onlyStrategy(addr) {
        if (!IStrategy(addr).paused()) {
            IStrategy(addr).pause();
            emit StrategyPause(addr, msg.sender, true);
        }
    }

    function unpauseStrategy(address addr) public onlyPauseController onlyStrategy(addr) {
        if (IStrategy(addr).paused()) {
            IStrategy(addr).unpause();
            emit StrategyPause(addr, msg.sender, false);
        }
    }

    function pauseStrategies(address[] memory strats) public onlyPauseController {
        uint256 i;
        for (i = 0; i < strats.length; i += 1) {
            pauseStrategy(strats[i]);
        }
    }

    function unpauseStrategies(address[] memory strats) public onlyPauseController {
        uint256 i;
        for (i = 0; i < strats.length; i += 1) {
            unpauseStrategy(strats[i]);
        }
    }

    function setStrategyGov(address addr, address _govAddress) public onlyOwner onlyStrategy(addr) {
        require(_govAddress != address(0));
        IStrategy(addr).setGov(_govAddress);
        emit StrategyGovSet(addr, _govAddress);
    }
}


