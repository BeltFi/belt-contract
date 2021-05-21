pragma solidity ^0.6.0;

interface IMigrations {
    function setCompleted(uint completed) external;
}

contract Migrations {
    address public owner;

    // A function with the signature `last_completed_migration()`, returning a uint, is required.
    uint public last_completed_migration;

    modifier restricted() {
        if (msg.sender == owner) _;
    }

    constructor() public {
        owner = msg.sender;
    }

    // A function with the signature `setCompleted(uint)` is required.
    function setCompleted(uint completed) public restricted {
        last_completed_migration = completed;
    }

    function upgrade(address new_address) public restricted {
        IMigrations(new_address).setCompleted(last_completed_migration);
    }

    function revert() public {
        require(last_completed_migration > 0, "require: initial migration");

        last_completed_migration = last_completed_migration - 1;
    }
}