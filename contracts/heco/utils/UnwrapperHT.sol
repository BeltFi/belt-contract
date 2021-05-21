pragma solidity 0.6.12;

interface IWHT {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract UnwrapperHT {
    using SafeERC20 for IERC20;

    address public whtAddress = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;

    function unwrapBNB(uint amount) public {
        IERC20 wht = IERC20(whtAddress);

        wht.safeTransferFrom(msg.sender, address(this), amount);
        require(wht.balanceOf(address(this)) >= amount);

        IWHT(whtAddress).withdraw(amount);
        require(address(this).balance >= amount);

        (bool res, ) = msg.sender.call{value: amount}("");
        require(res);
    }

    receive() external payable {}
    fallback() external payable {}
}
