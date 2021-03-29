pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

abstract contract StrategyToken is ERC20, ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public token;

    address public govAddress;

    uint256 public entranceFeeNumer;

    uint256 public entranceFeeDenom;

    // constructor (string memory name_, string memory symbol_) public ERC20(name_, symbol_) {}

    // deposit tokens to this minter and receive shares
    // tokens deposited this way remains in this contract until supplyStrategy is called
    function deposit(uint256 _amount, uint256 _minShares) virtual external;

    // return shares and receive tokens from strategy
    function withdraw(uint256 _shares, uint256 _minAmount) virtual external;

    // balance of tokens that this contract is holding
    function balance() virtual public view returns (uint256);

    // total balance of tokens of a strategy
    function balanceStrategy() virtual public view returns (uint256);

    // sum of all tokens in this contract and in a strategy.
    function calcPoolValueInToken() virtual public view returns (uint256);

    // calculate the number of tokens you can receive per share
    function getPricePerFullShare() virtual public view returns (uint256);

    // convert shares to amount of tokens 
    function sharesToAmount(uint256 _shares) virtual public view returns (uint256);

    // convert the amount of tokens to shares
    function amountToShares(uint256 _amount) virtual public view returns (uint256);

    function setGovAddress(address _govAddress) virtual public;

    function setEntranceFee(uint256 _entranceFeeNumer, uint256 _entranceFeeDenom) virtual external;
}

