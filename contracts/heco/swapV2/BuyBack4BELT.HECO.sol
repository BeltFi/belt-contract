pragma solidity 0.6.12;

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

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IStableSwap {
    function coins(int128 i) external view returns (address);
    function withdraw_buyback_fees() external;
}

interface IBeltToken {
    function token() external view returns (address);
    function withdraw(uint256 _shares, uint256 _minAmount) external;
}

interface IBEP20 {
    function balanceOf(address) external view returns (uint);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Buyback4BELT is Ownable {
    
    event BuyBack(address swap, address token, uint256 amount, uint256 beltBurned);
    
    address public swap;
    address public mdexRouter;
    
    uint256 public N_COINS = 4;
    
    address public constant wHTAddress = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;
    address public constant husdAddress = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;
    address public constant beltAddress = 0xE0e514c71282b6f4e823703a39374Cf58dc3eA4f;
    address public burnAddress = 0x000000000000000000000000000000000000dEaD;
    
    mapping(address => address[]) public wantToBELTPaths;
    
    // mainnet] 4BELT StableSwap
    // 0xAEA4f7dcd172997947809CE6F12018a6D5c1E8b6
    // mainnet] pcs router v2
    // 0x10ED43C718714eb63d5aA57B78B54704E256024E
    constructor(address _swap, address _mdexRouter) public {
        swap = _swap;
        mdexRouter = _mdexRouter;
        
        for(int128 i = 0; i < int128(N_COINS); i++) {
            address beltToken = IStableSwap(swap).coins(i);
            address token = IBeltToken(beltToken).token();
            
            if (token == husdAddress) {
                wantToBELTPaths[token] = [token, wHTAddress, beltAddress];    
            } else {
                wantToBELTPaths[token] = [token, husdAddress, wHTAddress, beltAddress];
            }
            
            
            IBEP20(beltToken).approve(beltToken, uint(-1));
        }
    }

    function setBurnAddress(address _burnAddress) public onlyOwner {
        burnAddress = _burnAddress;
    }
    
    function buyback() public onlyOwner {
        IStableSwap _swap = IStableSwap(swap);
        _swap.withdraw_buyback_fees();
        
        for(int128 i = 0; i < int128(N_COINS); i++) {
            address beltToken = _swap.coins(i);
            uint256 beltTokenBalance = IBEP20(beltToken).balanceOf(address(this));
            
            if (beltTokenBalance > 0) {
                IBeltToken(beltToken).withdraw(beltTokenBalance, 0);
                
                address token = IBeltToken(beltToken).token();
                
                uint256 balance = IBEP20(token).balanceOf(address(this));
                
                if (balance > 0) {
                    IBEP20(token).approve(mdexRouter, balance);
                    
                    uint[] memory amounts = IPancakeRouter02(mdexRouter).swapExactTokensForTokens(balance, 1, wantToBELTPaths[token], burnAddress, now + 15);
                    
                    emit BuyBack(swap, token, balance, amounts[amounts.length - 1]);
                }   
            }
        }
    }
    
    function withdraw(address token) public onlyOwner {
        IBEP20(token).transfer(owner(), IBEP20(token).balanceOf(address(this)));
    }
}
