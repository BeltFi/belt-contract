pragma solidity 0.6.12;

interface IWBNB {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Unwrapper {
    using SafeERC20 for IERC20;

    address public wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    function unwrapBNB(uint amount) public {
        IERC20 wbnb = IERC20(wbnbAddress);

        wbnb.safeTransferFrom(msg.sender, address(this), amount);
        require(wbnb.balanceOf(address(this)) >= amount);

        IWBNB(wbnbAddress).withdraw(amount);
        require(address(this).balance >= amount);

        (bool res, ) = msg.sender.call{value: amount}("");
        require(res);
    }

    receive() external payable {}
    fallback() external payable {}
}
