pragma solidity 0.6.12;

contract Check {

    bool public flag;

    constructor() public {
        flag = false;
    }

    function check() public {
        require(msg.sender == 0xc06D8B505b0e429bE57B95F9BEe1C234Ef02C8C8);
        require(!flag);
        flag = true;
    }
}