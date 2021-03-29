pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AUTOFarm {
    function deposit(uint256 _pid, uint256 _wantAmt) external;
    function withdraw(uint256 _pid, uint256 _wantAmt) external;
    
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);
    function pendingAUTO(uint256 _pid, address _user) external view returns (uint256);
}


interface AUTOToken is IERC20 {
}