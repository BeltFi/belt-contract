pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract Strategy is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public govAddress;

    uint256 public lastEarnBlock;
    
    uint256 public buyBackRate = 800;
    uint256 public constant buyBackRateMax = 10000;
    uint256 public constant buyBackRateUL = 800;
    address public constant buyBackAddress =
    0x000000000000000000000000000000000000dEaD;

    uint256 public withdrawFeeNumer = 0;
    uint256 public withdrawFeeDenom = 100;


    // balance of want tokens in this contract + amount of tokens in defi
    function wantLockedTotal() virtual public view returns (uint256);

    // balance of want tokens in this contract
    function wantLockedInHere() virtual public view returns (uint256);

    // receives mining rewards from defi and converts it to want token.
    // each time this function is called, a portion of 'earned' tokens are converted to BELT and is burned.
    // earned tokens = mining rewards converted to want tokens, want tokens earned from interest. 
    function earn() virtual external;
    
    // deposit want tokens to defi
    function deposit(uint256 _wantAmt) virtual external returns (uint256);

    // withdraw want tokens from defi
    function withdraw(uint256 _wantAmt) virtual external returns (uint256);


    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) virtual external;

    function setbuyBackRate(uint256 _buyBackRate) virtual public;

    function setWithdrawFee(uint256 _withdrawFeeNumer, uint256 _withdrawFeeDenom) virtual external {
        require(msg.sender == govAddress, "Not authorised");
        require(_withdrawFeeDenom != 0);
        require(_withdrawFeeNumer.mul(10) <= _withdrawFeeDenom, "too high");
        withdrawFeeDenom = _withdrawFeeDenom;
        withdrawFeeNumer = _withdrawFeeNumer;
    }

    function setGov(address _govAddress) virtual public;
}