pragma solidity 0.6.12;


interface IStrategy {
    function wantLockedTotal() external view returns (uint256);
    function wantLockedInHere() external view returns (uint256);
    function govAddress() external view returns (address);
    function lastEarnBlock() external view returns (uint256);
    function buyBackRate() external view returns (uint256);
    function buyBackRateMax() external view returns (uint256);
    function buyBackRateUL() external view returns (uint256);
    function buyBackAddress() external view returns (address);
    function withdrawFeeNumer() external view returns (uint256);
    function withdrawFeeDenom() external view returns (uint256);
    function paused() external view returns (bool);

    function deposit(uint256 _wantAmt) external returns (uint256);
    function withdraw(uint256 _wantAmt) external returns (uint256);
    function updateStrategy() external;

    function earn() external;

    // govFunctions
    function pause() external;
    function unpause() external;
    function setbuyBackRate(uint256 _buyBackRate) external;
    function setGov(address _govAddress) external;
    function setWithdrawFee(uint256 _withdrawFeeNumer, uint256 _withdrawFeeDenom) external;
    function inCaseTokensGetStuck(address _token, uint256 _amount, address _to) external;
    function setBNBHelper(address _helper) external;
}

interface ILeverageStrategy is IStrategy {
    function leverage(uint256 _amount) external;
    function deleverage(uint256 _amount) external;
    function deleverageAll(uint256 redeemFeeAmount) external;
    function updateBalance() external view returns (uint256 sup, uint256 brw, uint256 supMin);
    function borrowRate() external view returns (uint256);
    function setBorrowRate(uint256 _borrowRate) external;
    function setLeverageAdmin(address _leverageAdmin) external;
}
