pragma solidity 0.6.12;

import "./StrategyTokenV2.sol";
import "./MultiStrategyTokenStorageV2.sol";
import "../../interfaces/Wrapped.sol";
import "../../interfaces/IStrategyToken.sol";

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


contract MultiStrategyTokenV2 is Initializable, StrategyTokenV2, MultiStrategyTokenStorageV2 {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMathUpgradeable for uint256;

    event Deposit(address tokenAddress, uint256 depositAmount, uint256 sharesMinted, address strategyAddress);
    event Withdraw(address tokenAddress, uint256 withdrawAmount, uint256 sharesBurnt, address strategyAddress);
    event Rebalance(address strategyWithdrawn, address strategyDeposited, uint256 amountMoved);
    event RatioChanged(address strategyAddress, uint256 ratioBefore, uint256 ratioAfter);
    event StrategyActiveSet(address strategyAddress, bool isDeposit, bool value);
    event RebalanceThresholdSet(uint256 numer, uint256 denom);
    event StrategyAdded(address strategyAddress);
    event StrategyRemoved(address strategyAddress);

    function __MultiStrategyToken_init(
        string memory name_,
        string memory symbol_,
        address _token,
        address[] memory _strategies
    ) public initializer {
        __StrategyTokenV2_init(name_, symbol_, _token, msg.sender, 0, 1);
        __MultiStrategyTokenV2_init_unchained(_strategies);
    }

    function __MultiStrategyTokenV2_init_unchained(
        address[] memory _strategies
    ) internal initializer {
        // AUTOFARM
        // ACRYPTOS
        // ALPHAHOMORA
        // FORTUBE
        // VENUS
        // ELLIPSIS
        // ALPACA        
        strategies = _strategies;
        
        uint256 i;
        for (i = 0; i < strategies.length; i += 1) {
            ratios[strategies[i]] = 1;
            ratioTotal = ratioTotal.add(ratios[strategies[i]]);
        }

        for (i = 0; i < strategies.length; i += 1) {
            depositActive[strategies[i]] = true;
            withdrawActive[strategies[i]] = true;
        }
        depositActiveCount = strategies.length;        
        withdrawActiveCount = strategies.length;

        rebalanceThresholdNumer = 10;
        rebalanceThresholdDenom = 100;
    
        approveToken();
    }

    function approveToken() public {
        uint i = 0;
        for (; i < strategies.length; i += 1) {
            IERC20(token).safeApprove(strategies[i], uint(-1));
        }
    }

    function setGovAddress(address _govAddress) external {
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        govAddress = _govAddress;
    }

    function setPolicyAdmin(address _policyAdmin) external {
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        policyAdmin = _policyAdmin;
    }

    function pauseDeposit() external {
        require(!depositPaused, "deposit paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        depositPaused = true;
    }

    function unpauseDeposit() external {
        require(depositPaused, "deposit not paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        depositPaused = false;
    }

    function pauseWithdraw() external virtual {
        require(!withdrawPaused, "withdraw paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        withdrawPaused = true;
    }

    function unpauseWithdraw() external virtual {
        require(withdrawPaused, "withdraw not paused");
        require(msg.sender == govAddress || msg.sender == owner(), "Not authorized");
        withdrawPaused = false;
    }

    function deposit(uint256 _amount, uint256 _minShares)
        external
    {
        require(!depositPaused, "deposit paused");
        require(_amount != 0, "deposit must be greater than 0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_amount, _minShares);
    }

    function depositBNB(uint256 _minShares) external payable {
        require(!depositPaused, "deposit paused");
        require(isWBNB, "not bnb");
        require(msg.value != 0, "deposit must be greater than 0");
        _wrapBNB(msg.value);
        _deposit(msg.value, _minShares);
    }

    function _deposit(uint256 _amount, uint256 _minShares)
        internal
        nonReentrant
    {
        updateAllStrategies();
        uint256 _pool = calcPoolValueInToken();
        
        address strategyAddress;
        (strategyAddress,) = findMostInsufficientStrategy();
        ISingleStrategyToken(strategyAddress).deposit(_amount, 0);
        uint256 sharesToMint = calcPoolValueInToken().sub(_pool);
        if (totalSupply() != 0 && _pool != 0) {
            sharesToMint = sharesToMint.mul(totalSupply())
                .div(_pool);
        }
        require(sharesToMint >= _minShares, "did not meet minimum shares requested");

        _mint(msg.sender, sharesToMint);

        emit Deposit(token, _amount, sharesToMint, strategyAddress);
    }
    

    function withdraw(uint256 _shares, uint256 _minAmount)
        external
    {
        uint r = _withdraw(_shares, _minAmount);
        IERC20(token).safeTransfer(msg.sender, r);
    }

    function withdrawBNB(uint256 _shares, uint256 _minAmount)
        external
    {
        require(isWBNB, "not bnb");
        uint256 r = _withdraw(_shares, _minAmount);
        _unwrapBNB(r);
        msg.sender.transfer(r);
    }

    function _withdraw(uint256 _shares, uint256 _minAmount)
        internal
        nonReentrant
        returns (uint256)
    {
        require(!withdrawPaused, "withdraw paused");
        require(_shares != 0, "shares must be greater than 0");

        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");

        updateAllStrategies();
        uint256 pool = calcPoolValueInToken();

        uint256 r = pool.mul(_shares).div(totalSupply());
        _burn(msg.sender, _shares);

        address strategyToWithdraw;
        uint256 strategyAvailableAmount;
        (strategyToWithdraw, strategyAvailableAmount) = findMostOverLockedStrategy(r);
        if (r > strategyAvailableAmount) {
            (strategyToWithdraw, strategyAvailableAmount) = findMostLockedStrategy();
            require(r <= strategyAvailableAmount, "withdrawal amount too big");
        }
        uint256 _stratPool = ISingleStrategyToken(strategyToWithdraw).calcPoolValueInToken();
        uint256 stratShares = r
            .mul(
                IERC20(strategyToWithdraw).totalSupply()
            )
            .div(_stratPool);
        uint256 diff = balance();
        ISingleStrategyToken(strategyToWithdraw).withdraw(stratShares, 0/*strategyAvailableAmount*/);
        diff = balance().sub(diff);
        
        require(diff >= _minAmount, "did not meet minimum amount requested");

        emit Withdraw(token, diff, _shares, strategyToWithdraw);

        return diff;
    }

    function rebalance() public {
        require(msg.sender == govAddress || msg.sender == policyAdmin || msg.sender == owner(), "Not authorized");
        address strategyToWithdraw;
        uint256 strategyAvailableAmount;
        address strategyToDeposit;
        // uint256 strategyInsuffAmount;
        updateAllStrategies();
        (strategyToWithdraw, strategyAvailableAmount) = findMostOverLockedStrategy(0);
        (strategyToDeposit, /*strategyInsuffAmount*/) = findMostInsufficientStrategy();

        uint256 totalBalance = calcPoolValueInToken();
        uint256 optimal = totalBalance.mul(ratios[strategyToWithdraw]).div(ratioTotal);

        uint256 threshold = optimal.mul(
                rebalanceThresholdNumer
        ).div(rebalanceThresholdDenom);

        if (strategyAvailableAmount != 0 && threshold < strategyAvailableAmount) {
            uint256 _pool = ISingleStrategyToken(strategyToWithdraw).calcPoolValueInToken();
            uint256 stratShares = strategyAvailableAmount
                    .mul(
                        IERC20(strategyToWithdraw).totalSupply()
                    )
                    .div(_pool);
            uint256 diff = balance();
            ISingleStrategyToken(strategyToWithdraw).withdraw(stratShares, 0/*strategyAvailableAmount)*/);
            diff = balance().sub(diff);
            ISingleStrategyToken(strategyToDeposit).deposit(diff, 0);
            emit Rebalance(strategyToWithdraw, strategyToDeposit, diff);
        }
    }

    function findMostOverLockedStrategy(uint256 withdrawAmt) public view returns (address, uint256) {
        address[] memory strats = getAvailableStrategyList(false);

        uint256 totalBalance = calcPoolValueInToken().sub(withdrawAmt);

        address overLockedStrategy = strats[0];

        uint256 optimal = totalBalance.mul(ratios[strats[0]]).div(ratioTotal);
        uint256 current = getBalanceOfOneStrategy(strats[0]);   
        
        bool isLessThanOpt = current < optimal;
        uint256 overLockedBalance = isLessThanOpt ? optimal.sub(current) : current.sub(optimal);

        uint256 i = 1;
        for (; i < strats.length; i += 1) {
            optimal = totalBalance.mul(ratios[strats[i]]).div(ratioTotal);
            current = getBalanceOfOneStrategy(strats[i]); 
            if (isLessThanOpt && current >= optimal) {
                isLessThanOpt = false;
                overLockedBalance = current.sub(optimal);
                overLockedStrategy = strats[i];
            } else if (isLessThanOpt && current < optimal) {
                if (optimal.sub(current) < overLockedBalance) {
                    overLockedBalance = optimal.sub(current);
                    overLockedStrategy = strats[i];
                }
            } else if (!isLessThanOpt && current >= optimal) {
                if (current.sub(optimal) > overLockedBalance) {
                    overLockedBalance = current.sub(optimal);
                    overLockedStrategy = strats[i];
                }
            }
        }

        if (isLessThanOpt) {
            overLockedBalance = 0;
        }

        return (overLockedStrategy, overLockedBalance);
    }

    function findMostLockedStrategy() public view returns (address, uint256) {
        address[] memory strats = getAvailableStrategyList(false);

        uint256 current;
        address lockedMostAddr = strats[0];
        uint256 lockedBalance = getBalanceOfOneStrategy(strats[0]);

        uint256 i = 1;
        for (; i < strats.length; i += 1) {
            current = getBalanceOfOneStrategy(strats[i]); 
            if (current > lockedBalance) {
                lockedBalance = current;
                lockedMostAddr = strats[i];
            }
        }

        return (lockedMostAddr, lockedBalance);
    }

    function findMostInsufficientStrategy() public view returns (address, uint256) {
        address[] memory strats = getAvailableStrategyList(true);

        uint256 totalBalance = calcPoolValueInToken();

        address insuffStrategy = strats[0];

        uint256 optimal = totalBalance.mul(ratios[strats[0]]).div(ratioTotal);
        uint256 current = getBalanceOfOneStrategy(strats[0]);
        
        bool isGreaterThanOpt = current > optimal;
        uint256 insuffBalance = isGreaterThanOpt ? current.sub(optimal) : optimal.sub(current);

        uint256 i = 1;
        for (; i < strats.length; i += 1) {
            optimal = totalBalance.mul(ratios[strats[i]]).div(ratioTotal);
            current = getBalanceOfOneStrategy(strats[i]); 
            if (isGreaterThanOpt && current < optimal) {
                isGreaterThanOpt = false;
                insuffBalance = optimal.sub(current);
                insuffStrategy = strats[i];
            } else if (isGreaterThanOpt && current > optimal) {
                if (current.sub(optimal) < insuffBalance) {
                    insuffBalance = current.sub(optimal);
                    insuffStrategy = strats[i];
                }
            } else if (!isGreaterThanOpt && current <= optimal) {
                if (optimal.sub(current) > insuffBalance) {
                    insuffBalance = optimal.sub(current);
                    insuffStrategy = strats[i];
                }
            }
        }

        if (isGreaterThanOpt) {
            insuffBalance = 0;
        }

        return (insuffStrategy, insuffBalance);
    }

    function balance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getBalanceOfOneStrategy(address strategyAddress) public view returns (uint256 bal) {
            ISingleStrategyToken stToken = ISingleStrategyToken(strategyAddress);
            if (stToken.balanceOf(address(this)) != 0) {
                bal = stToken.calcPoolValueInToken().mul(
                    stToken.balanceOf(address(this))
                ).div(
                    stToken.totalSupply()
                );
            } else {
                bal = 0;
            }
    }

    function balanceStrategy() public view returns (uint256) {
        uint i = 0;
        uint sum = 0;
        for (; i < strategies.length; i += 1) {
            sum = sum.add(getBalanceOfOneStrategy(strategies[i]));
        }
        return sum;
    }

    function getAvailableStrategyList(bool isDeposit) internal view returns (address[] memory) {
        uint256 activeCnt = isDeposit ? depositActiveCount : withdrawActiveCount;
        require(activeCnt != 0, "none of the strategies are active");
        address[] memory addrArr = new address[](activeCnt);
        uint256 i = 0;
        uint256 cnt = 0;
        for (; i < strategies.length; i += 1) {
            if (isDeposit) {
                if (depositActive[strategies[i]]) {
                    addrArr[cnt] = strategies[i];
                    cnt += 1;
                }
            } else {
                if (withdrawActive[strategies[i]]) {
                    addrArr[cnt] = strategies[i];
                    cnt += 1;
                }
            }
        }

        return addrArr;
    }

    function calcPoolValueInToken() public view returns (uint256) {
        return balanceStrategy();
    }

    function getPricePerFullShare() public view returns (uint) {
        uint _pool = calcPoolValueInToken();
        return _pool.mul(1e18).div(totalSupply());
    }

    function changeRatio(uint256 index, uint256 value) external {
        require(msg.sender == govAddress || msg.sender == policyAdmin || msg.sender == owner(), "Not authorized");
        // require(index != 0);
        require(strategies.length > index, "invalid index");
        uint256 valueBefore = ratios[strategies[index]];
        ratios[strategies[index]] = value;    
        ratioTotal = ratioTotal.sub(valueBefore).add(value);

        emit RatioChanged(strategies[index], valueBefore, value);
    }

    // doesn"t guarantee that withdrawing shares returned by this function will always be successful.
    function getMaxWithdrawableShares() public view returns (uint256) {
        require(totalSupply() != 0, "total supply is 0");
        uint256 bal;
        (, bal) = findMostLockedStrategy();
        return amountToShares(bal);
    }

    function sharesToAmount(uint256 _shares) public view returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        return _shares.mul(_pool).div(totalSupply());
    }

    function amountToShares(uint256 _amount) public view returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        uint256 shares;
        if (totalSupply() == 0 || _pool == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply()))
                .div(_pool);
        }
        return shares;
    }
    
    function setStrategyActive(uint256 index, bool isDeposit, bool b) public {
        require(msg.sender == govAddress || msg.sender == policyAdmin || msg.sender == owner(), "Not authorized");
        mapping(address => bool) storage isActive = isDeposit ? depositActive : withdrawActive;
        require(index < strategies.length, "invalid index");
        require(isActive[strategies[index]] != b, b ? "already active" : "already inactive");
        if (isDeposit) {
            depositActiveCount = b ? depositActiveCount.add(1) : depositActiveCount.sub(1);
        } else {
            withdrawActiveCount = b ? withdrawActiveCount.add(1) : withdrawActiveCount.sub(1);
        }
        isActive[strategies[index]] = b;

        emit StrategyActiveSet(strategies[index], isDeposit, b);
    }

    function setRebalanceThreshold(uint256 _rebalanceThresholdNumer, uint256 _rebalanceThresholdDenom) external {
        require(msg.sender == govAddress || msg.sender == policyAdmin || msg.sender == owner(), "Not authorized");
        require(_rebalanceThresholdDenom != 0, "denominator should not be 0");
        require(_rebalanceThresholdDenom >= _rebalanceThresholdNumer, "denominator should be greater than or equal to the numerator");
        rebalanceThresholdNumer = _rebalanceThresholdNumer;
        rebalanceThresholdDenom = _rebalanceThresholdDenom;

        emit RebalanceThresholdSet(rebalanceThresholdNumer, rebalanceThresholdDenom);
    }

    function strategyCount() public view returns (uint256) {
        return strategies.length;
    }


    function _wrapBNB(uint256 _amount) internal {
        if (address(this).balance >= _amount) {
            IWBNB(wbnbAddress).deposit{value: _amount}();
        }
    }

    function _unwrapBNB(uint256 _amount) internal {
        uint256 wbnbBal = IERC20(wbnbAddress).balanceOf(address(this));
        if (wbnbBal >= _amount) {
            IERC20(wbnbAddress).safeApprove(bnbHelper, _amount);
            IUnwrapper(bnbHelper).unwrapBNB(_amount);
        }
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress || msg.sender == owner(), "!gov");
        require(_token != address(this), "!safe");
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "amount greater than holding");
            _wrapBNB(_amount);
            _token = wbnbAddress;
        } else if (_token == token) { 
            require(balance() >= _amount, "amount greater than holding");
        }
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function getProxyAdmin() public view returns (address adm) {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            adm := sload(slot)
        }
    }

    function setBNBHelper(address _helper) public {
        require(msg.sender == govAddress || msg.sender == owner(), "!gov");
        require(_helper != address(0));

        bnbHelper = _helper;
    }

    function updateAllStrategies() public {
        uint8 i = 0;
        for (; i < strategies.length; i += 1) {
            ISingleStrategyToken(strategies[i]).updateStrategy();
        }
    }

    function getStrategyIndex(address strategyAddress) public view returns (uint8) {
        for (uint8 i = 0; i < strategies.length; i++) {
            if (strategies[i] == strategyAddress) return i;
        }
        revert("invalid strategy address");
    }

    function addStrategy(address strategyAddress) internal {
        uint8 i = 0;
        for (; i < strategies.length; i += 1) {
            require(strategies[i] != strategyAddress, "Strategy Already Exists");
        }
        strategies.push(strategyAddress);
        IERC20(token).safeApprove(strategyAddress, uint(-1));
        emit StrategyAdded(strategyAddress);
    }

    function removeStrategy(address strategyAddress) internal {
        uint8 index = getStrategyIndex(strategyAddress);
        require(index < strategies.length);

        address strategyToRemove = strategies[index];
        for (uint8 i = index + 1; i < strategies.length; i++) {
            strategies[i - 1] = strategies[i];
        }
        
        IERC20(token).safeApprove(strategyToRemove, 0);
        
        strategies[strategies.length - 1] = strategyToRemove;
        strategies.pop();

        ratioTotal = ratioTotal.sub(ratios[strategyToRemove]);
        ratios[strategyToRemove] = 0;
        
        if (depositActive[strategyToRemove]) {
            depositActiveCount = depositActiveCount.sub(1);
            depositActive[strategyToRemove] = false;
        }
        if (withdrawActive[strategyToRemove]) {
            withdrawActiveCount = withdrawActiveCount.sub(1);
            withdrawActive[strategyToRemove] = false;
        }
        emit StrategyRemoved(strategyToRemove);
    }

    // function addMoreStrategies() public {
    //     require(msg.sender == govAddress || msg.sender == owner(), "!gov");
    // }

    fallback() external payable {}
    receive() external payable {}
}
