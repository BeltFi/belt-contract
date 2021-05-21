pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

abstract contract Strategy is Ownable, ReentrancyGuard, Pausable {
    address public govAddress;

    uint256 public lastEarnBlock;
    
    uint256 public buyBackRate = 800;
    uint256 public constant buyBackRateMax = 10000;
    uint256 public constant buyBackRateUL = 800;
    
    address public buyBackAddress =
    0x000000000000000000000000000000000000dEaD;

    uint256 public withdrawFeeNumer = 0;
    uint256 public withdrawFeeDenom = 100;
}
