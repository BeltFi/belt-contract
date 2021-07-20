pragma solidity 0.6.12;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract BeltProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data) public TransparentUpgradeableProxy(_logic, admin_, _data){ }

    function getAdmin() public view returns (address) {
        return _admin();
    }
    
    function getImplementation() public view returns (address) {
        return _implementation();
    }
}

contract ReceivableBeltProxy is BeltProxy {
    constructor(address _logic, address admin_, bytes memory _data) public BeltProxy(_logic, admin_, _data){ }    
    receive() override external payable {}
}