pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract StrategyToken is ERC20, ReentrancyGuard, Ownable {
    address public token;

    address public govAddress;

    uint256 public entranceFeeNumer;

    uint256 public entranceFeeDenom;

    bool public depositPaused;

    bool public withdrawPaused;
}
