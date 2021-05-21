pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this;
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IBeltSwapView {
    struct SwapInfo {
        address user;
        address lpToken;
        uint256 lpTotalSupply;
        uint256 balance;
        uint256 allowance;
        uint256 allowanceSwap;
        uint256 virtualPrice;
        uint256 A;
        uint256 buyback_fee;
        uint256 fee;
        address[] coins;
        uint256[] totalSupplies;
        uint256[] volumes;
        uint256[] reserves;
        uint256[] depositAllowances;
        uint256[] swapAllowances;
        uint256[] balances;
    }
    struct FarmingInfo {
        address vault;
        address token;
        uint256 pid;
        uint256 allowance;
        uint256 deposit;
        uint256 balance;
        uint256 reward;
        uint256 totalLocked;
    }

    function version() external pure returns (string memory);
    function getSwapStat(address user,address depositor) external view returns(SwapInfo memory info);
    function getUserBeltStat(address user) external view returns(FarmingInfo[] memory info);
}

interface IBeltVaultView {
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
    function version() external pure returns (string memory);
    function getVaultStat(address user, address minter) external view returns(VaultInfo memory info);
}

contract BeltView is Ownable {
    address public swapView;
    address public vaultView;

    constructor(address _swapView, address _vaultView) public {
        swapView = _swapView;
        vaultView = _vaultView;
    }

    function setSwapView(address _newSwapView) public onlyOwner {
        require(_newSwapView != address(0));

        swapView = _newSwapView;
    }

    function setVaultView(address _newVaultView) public onlyOwner {
        require(_newVaultView != address(0));

        vaultView = _newVaultView;
    }

    function getSwapStat(address user,address depositor) external view returns(IBeltSwapView.SwapInfo memory info) {
        return IBeltSwapView(swapView).getSwapStat(user, depositor);
    }

    function getUserBeltStat(address user) external view returns(IBeltSwapView.FarmingInfo[] memory info) {
        return IBeltSwapView(swapView).getUserBeltStat(user);
    }

    function getVaultStat(address user, address minter) external view returns(IBeltVaultView.VaultInfo memory info) {
        return IBeltVaultView(vaultView).getVaultStat(user, minter);
    }
}