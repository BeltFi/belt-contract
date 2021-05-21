pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IMasterBelt {
    function userInfo(uint, address) external view returns (uint, uint);
    function poolLength() external view returns (uint);
    function poolInfo(uint) external view returns (address, uint, uint, uint, address);
    function pendingBELT(uint256 _pid, address _user) external view returns (uint256);
}

interface IBEP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
    function balanceOf(address) external view returns (uint);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function totalSupply() external view returns (uint256);
}

interface IStrategyToken {
    function token() external view returns (address);
    function isWbnb() external view returns (bool);
    function strategy() external view returns (address);
    function strategies(uint256 idx) external view returns (address);
    function depositActiveCount() external view returns (uint256);
    function withdrawActiveCount() external view returns (uint256);
    function strategyCount() external view returns (uint256);
    function ratios(address _strategy) external view returns (uint256);
    function depositActive(address _strategy) external view returns (bool);
    function withdrawActive(address _strategy) external view returns (bool);
    function ratioTotal() external view returns (uint256);
    function balanceStrategy() external view returns (uint256);
    function getBalanceOfOneStrategy(address strategyAddress) external view returns (uint256);
    function getPricePerFullShare() external view returns (uint);
    function calcPoolValueInToken() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IMultiStrategyToken {
    function deposit(uint256 _amount, uint256 _minShares) external;
    function depositBNB(uint256 _minShares) external payable;
    function withdraw(uint256 _shares, uint256 _minAmount) external;
    function withdrawBNB(uint256 _shares, uint256 _minAmount) external;
}

contract BeltVaultView {
    address public masterBelt;

    struct VaultInfo {
        address token;
        address bToken;
        bool isWbnb;

        uint256 strategyCount;
        uint256 totalLockedWant;

        address[] minters;
        address[] strategies;
        uint256[] ratios;
        uint256[] strategyBalances;
        bool[] isDepositActive;
        bool[] isWithdrawActive;

        uint256 balance;
        uint256 balanceB;

        uint256 decimals;
        uint256 decimalsB;

        uint256 allowanceTokenToMinter;
        uint256 allowanceBtoMasterBelt;

        uint256 totalSupplyB;
    }

    constructor(address _masterBelt) public {
        masterBelt = _masterBelt;
    }

    function version() public pure returns (string memory) {
        return "v3";
    }

    function getVaultStat(address user, address minter) public view returns(VaultInfo memory info){
        // IStrategyToken token = IStrategyToken(minter);

        uint256 balance = 0;
        uint256 balanceB = 0;
        uint256 allowance = 0;
        uint256 allowanceB = 0;
        uint256 decimals = 18;

        // uint256 strategyCount = token.strategyCount();
        address[] memory strategies = new address[](IStrategyToken(minter).strategyCount());
        address[] memory minters = new address[](IStrategyToken(minter).strategyCount());
        bool[] memory isDepositActive = new bool[](IStrategyToken(minter).strategyCount());
        bool[] memory isWithdrawActive = new bool[](IStrategyToken(minter).strategyCount());
        uint256[] memory strategyRatios = new uint256[](IStrategyToken(minter).strategyCount());
        uint256[] memory strategyBalances = new uint256[](IStrategyToken(minter).strategyCount());

        if (user != address(0)) {
            if (IStrategyToken(minter).isWbnb()) {
                balance = address(user).balance;
            } else {
                balance = IBEP20(IStrategyToken(minter).token()).balanceOf(user);
            }

            balanceB = IBEP20(minter).balanceOf(user);

            allowance = IBEP20(IStrategyToken(minter).token()).allowance(user, minter);
            allowanceB = IBEP20(minter).allowance(user, masterBelt);
        }

        if (!IStrategyToken(minter).isWbnb()) {
            decimals = IBEP20(IStrategyToken(minter).token()).decimals();
        }

        for(uint i = 0; i < IStrategyToken(minter).strategyCount(); i++) {
            minters[i] = IStrategyToken(minter).strategies(i);
            strategies[i] = IStrategyToken(minters[i]).strategy();
            strategyRatios[i] = IStrategyToken(minter).ratios(minters[i]);
            strategyBalances[i] = IStrategyToken(minter).getBalanceOfOneStrategy(minters[i]);
            isDepositActive[i] = IStrategyToken(minter).depositActive(minters[i]);
            isWithdrawActive[i] = IStrategyToken(minter).withdrawActive(minters[i]);
        }

        return VaultInfo(
            IStrategyToken(minter).token(), minter, IStrategyToken(minter).isWbnb(), IStrategyToken(minter).strategyCount(), IStrategyToken(minter).calcPoolValueInToken(), minters, strategies, strategyRatios,
            strategyBalances, isDepositActive, isWithdrawActive,
            balance, balanceB, decimals, IBEP20(minter).decimals(), allowance, allowanceB, IBEP20(minter).totalSupply()
        );
    }
}