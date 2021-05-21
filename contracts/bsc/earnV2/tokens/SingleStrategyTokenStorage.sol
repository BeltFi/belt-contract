pragma solidity 0.6.12;

import "./StrategyToken.sol";

abstract contract SingleStrategyTokenStorage is StrategyToken {

    address public strategy;

    address public constant wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    bool public isWbnb;

    address public bnbHelper;
}
