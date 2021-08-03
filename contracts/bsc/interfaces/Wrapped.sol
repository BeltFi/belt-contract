pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface Wrapped is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

interface IWBNB is Wrapped {
}

interface IWHT is Wrapped {
}


interface IUnwrapper {
    function unwrapBNB(uint256) external;
}