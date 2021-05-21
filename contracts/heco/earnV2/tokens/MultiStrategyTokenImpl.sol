pragma solidity 0.6.12;

import "./MultiStrategyTokenStorage.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface StrategyTokenLike {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function deposit(uint256 _amount, uint256 _minShares) external;
    function withdraw(uint256 _shares, uint256 _minAmount) external;
    function balance() external view returns (uint256);
    function balanceStrategy() external view returns (uint256);
    function calcPoolValueInToken() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function sharesToAmount(uint256 _shares) external view returns (uint256);
    function amountToShares(uint256 _amount) external view returns (uint256);
    function setEntranceFee(uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) external;
    function updateStrategy() external;
}

interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

interface HelperLike {
    function unwrapBNB(uint256) external;
}

contract MultiStrategyTokenImpl is MultiStrategyTokenStorage {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    
    constructor () public ERC20("", ""){}

    function setGovAddress(address _govAddress) external {
        require(msg.sender == govAddress, "Not authorized");
        govAddress = _govAddress;
    }

    function setPolicyAdmin(address _policyAdmin) external {
        require(msg.sender == govAddress, "Not authorized");
        policyAdmin = _policyAdmin;
    }

    function pauseDeposit() external {
        require(!depositPaused, "deposit paused");
        require(msg.sender == govAddress, "Not authorized");
        depositPaused = true;
    }

    function unpauseDeposit() external {
        require(depositPaused, "deposit not paused");
        require(msg.sender == govAddress, "Not authorized");
        depositPaused = false;
    }

    function pauseWithdraw() external virtual {
        require(!withdrawPaused, "withdraw paused");
        require(msg.sender == govAddress, "Not authorized");
        withdrawPaused = true;
    }

    function unpauseWithdraw() external virtual {
        require(withdrawPaused, "withdraw not paused");
        require(msg.sender == govAddress, "Not authorized");
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
        require(isWbnb, "not bnb");
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
        StrategyTokenLike(strategyAddress).deposit(_amount, 0);
        uint256 sharesToMint = calcPoolValueInToken().sub(_pool);
        if (totalSupply() != 0 && _pool != 0) {
            sharesToMint = sharesToMint.mul(totalSupply())
                .div(_pool);
        }
        require(sharesToMint >= _minShares, "did not meet minimum shares requested");
        _mint(msg.sender, sharesToMint);    
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
        require(isWbnb, "not bnb");
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
        uint256 _stratPool = StrategyTokenLike(strategyToWithdraw).calcPoolValueInToken();
        uint256 stratShares = r
            .mul(
                IERC20(strategyToWithdraw).totalSupply()
            )
            .div(_stratPool);
        uint256 diff = balance();
        StrategyTokenLike(strategyToWithdraw).withdraw(stratShares, 0/*strategyAvailableAmount*/);
        diff = balance().sub(diff);
        
        require(diff >= _minAmount, "did not meet minimum amount requested");

        return diff;
    }

    function rebalance() public {
        require(msg.sender == govAddress || msg.sender == policyAdmin, "Not authorized");
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
            uint256 _pool = StrategyTokenLike(strategyToWithdraw).calcPoolValueInToken();
            uint256 stratShares = strategyAvailableAmount
                    .mul(
                        IERC20(strategyToWithdraw).totalSupply()
                    )
                    .div(_pool);
            uint256 diff = balance();
            StrategyTokenLike(strategyToWithdraw).withdraw(stratShares, 0/*strategyAvailableAmount)*/);
            diff = balance().sub(diff);
            StrategyTokenLike(strategyToDeposit).deposit(diff, 0);
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
            StrategyTokenLike stToken = StrategyTokenLike(strategyAddress);
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
        require(msg.sender == govAddress || msg.sender == policyAdmin, "Not authorized");
        // require(index != 0);
        require(strategies.length > index, "invalid index");
        uint256 valueBefore = ratios[strategies[index]];
        ratios[strategies[index]] = value;    
        ratioTotal = ratioTotal.sub(valueBefore).add(value);
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
        require(msg.sender == govAddress || msg.sender == policyAdmin, "Not authorized");
        mapping(address => bool) storage isActive = isDeposit ? depositActive : withdrawActive;
        require(index < strategies.length, "invalid index");
        require(isActive[strategies[index]] != b, b ? "already active" : "already inactive");
        if (isDeposit) {
            depositActiveCount = b ? depositActiveCount.add(1) : depositActiveCount.sub(1);
        } else {
            withdrawActiveCount = b ? withdrawActiveCount.add(1) : withdrawActiveCount.sub(1);
        }
        isActive[strategies[index]] = b;
    }

    function setRebalanceThreshold(uint256 _rebalanceThresholdNumer, uint256 _rebalanceThresholdDenom) external {
        require(msg.sender == govAddress || msg.sender == policyAdmin, "Not authorized");
        require(_rebalanceThresholdDenom != 0, "denominator should not be 0");
        require(_rebalanceThresholdDenom >= _rebalanceThresholdNumer, "denominator should be greater than or equal to the numerator");
        rebalanceThresholdNumer = _rebalanceThresholdNumer;
        rebalanceThresholdDenom = _rebalanceThresholdDenom;
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
            HelperLike(bnbHelper).unwrapBNB(_amount);
        }
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
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
        require(msg.sender == govAddress, "!gov");
        require(_helper != address(0));

        bnbHelper = _helper;
    }

    function updateAllStrategies() public {
        uint8 i = 0;
        for (; i < strategies.length; i += 1) {
            StrategyTokenLike(strategies[i]).updateStrategy();
        }
    }

    // function addStrategy() public {
    //     require(msg.sender == govAddress, "!gov");
    //     address bunnyStrategyAddress = ;
    //     address fulcrumStrategyAddress = ;

    //     strategies.push(bunnyStrategyAddress);
    //     strategies.push(fulcrumStrategyAddress);
        
    //     IERC20(token).safeApprove(bunnyStrategyAddress, uint(-1));
    //     IERC20(token).safeApprove(fulcrumStrategyAddress, uint(-1));
    // }

    fallback() external payable {}
    receive() external payable {}
}
