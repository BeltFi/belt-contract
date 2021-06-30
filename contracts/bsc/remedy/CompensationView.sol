pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface IBEP20 {
    function balanceOf(address) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
}

interface ICompensationPool {
    function token4Belt() external view returns (address);
    function remedy4Belt() external view returns (address);
    function masterBELT() external view returns (address);
    
    function staked(address user) external view returns (uint);
    function pendingBELT(address user) external view returns (uint);
}

contract CompensationView {
    address public compensationPool;
    
    struct CompensationInfo{
        address user;
        address pool;
        
        uint256 allowance4BELT;
        uint256 allowanceR4BELT;
        
        uint256 balance4BELT;
        uint256 balanceR4BELT;
        
        uint256 staked;
        uint256 reward;
    }
    
    function getCompensationStat(address user) public view returns (CompensationInfo memory info) {
        ICompensationPool pool = ICompensationPool(compensationPool);
        
        IBEP20 token4BELT = IBEP20(pool.token4Belt());
        IBEP20 tokenR4BELT = IBEP20(pool.remedy4Belt());
        
        info = CompensationInfo(
            user, compensationPool, token4BELT.allowance(user, compensationPool), tokenR4BELT.allowance(user, compensationPool),
            token4BELT.balanceOf(user), tokenR4BELT.balanceOf(user),
            pool.staked(user), pool.pendingBELT(user)
        );
    }
}
