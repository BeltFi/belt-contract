pragma solidity 0.6.12;

import "./StrategyToken.sol";

abstract contract SingleStrategyTokenStorage is StrategyToken {

    address public strategy;

    address public constant wbnbAddress = 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F;
    
    bool public isWbnb;

    address public bnbHelper;
}
