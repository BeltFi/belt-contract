pragma solidity 0.6.12;

import "./Strategy.sol";
import "../defi/autoFarm.sol";
import "../defi/pancake.sol";


contract StrategyAUTOSingle is Strategy {
    address immutable public wantAddress;

    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant autoAddress =
    0xa184088a740c695E156F91f5cC086a06bb78b827;
    address public constant autoFarmAddress =
    0x0895196562C7868C5Be92459FaE7f877ED450452;

    
    // only updated when deposit / withdraw / earn is called
    uint256 public balanceSnapshot;

    // 1 = WBNB, 3 = BTCB, 4 = ETH
    uint256 public immutable poolId;

    address immutable public BELTAddress;

    address[] public autoToWantPath;
    address[] public autoToBELTPath;
    address[] public wantToBELTPath;

    constructor(
        address _BELTAddress,
        address _wantAddress,
        address _uniRouterAddress,
        uint256 _poolId,
        address[] memory _autoToWantPath,
        address[] memory _autoToBELTPath,
        address[] memory _wantToBETLPATH
    ) public {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;

        wantAddress = _wantAddress;

        poolId = _poolId;

        autoToWantPath = _autoToWantPath;
        autoToBELTPath = _autoToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        uniRouterAddress = _uniRouterAddress;

        IERC20(autoAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(autoFarmAddress, uint256(-1));
    }

    function deposit(uint256 _wantAmt)
        override
        public
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        uint256 before = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this));
        AUTOFarm(autoFarmAddress).deposit(poolId, _wantAmt);
        uint256 diff = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this)).sub(before);
        balanceSnapshot = balanceSnapshot.add(
            diff
        );
        return diff;
    }

    function earn() override external whenNotPaused {
        AUTOFarm(autoFarmAddress).withdraw(poolId, 0);

        uint256 prevBalance = balanceSnapshot;
        uint256 currentBalance = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this));

        uint256 earnedAmt = IERC20(autoAddress).balanceOf(address(this));
        earnedAmt = buyBack(earnedAmt);

        if (autoAddress != wantAddress) {
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                earnedAmt,
                0,
                autoToWantPath,
                address(this),
                now.add(600)
            );
        }
        if (currentBalance > prevBalance) {
            earnedAmt = currentBalance.sub(prevBalance);
            buyBackWant(earnedAmt);
        }
        earnedAmt = IERC20(wantAddress).balanceOf(address(this));
        if (earnedAmt != 0) {
            AUTOFarm(autoFarmAddress).deposit(poolId, earnedAmt);
        }
        currentBalance = AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this));
        balanceSnapshot = currentBalance > balanceSnapshot ? currentBalance : balanceSnapshot;
        lastEarnBlock = block.number;
    }

    function buyBackWant(uint256 _earnedAmt) internal {
        if (buyBackRate != 0) {
            uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);
            uint256 curWantBal = IERC20(wantAddress).balanceOf(address(this));
            if (curWantBal < buyBackAmt) {
                AUTOFarm(autoFarmAddress).withdraw(poolId, buyBackAmt.sub(curWantBal));
            }
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                buyBackAmt,
                0,
                wantToBELTPath,
                address(this),
                now + 600
            );

            uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
            IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);        
        }
    }

    function buyBack(uint256 _earnedAmt) internal returns (uint256) {
        if (buyBackRate <= 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

        IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
            buyBackAmt,
            0,
            autoToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);

        return _earnedAmt.sub(buyBackAmt);
    }

    function withdraw(uint256 _wantAmt)
        override
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        _wantAmt = _wantAmt.mul(withdrawFeeDenom.sub(withdrawFeeNumer)).div(withdrawFeeDenom);
        balanceSnapshot = balanceSnapshot.sub(
            _wantAmt
        );
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        AUTOFarm(autoFarmAddress).withdraw(poolId, _wantAmt);
        wantBal = IERC20(wantAddress).balanceOf(address(this)).sub(wantBal);
        IERC20(wantAddress).safeTransfer(owner(), wantBal);
        return wantBal;
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");

        _pause();

        IERC20(autoAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(autoFarmAddress, 0);
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();

        IERC20(autoAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(autoFarmAddress, uint256(-1));
    }

    function wantLockedTotal() override public view returns (uint256) {
        return wantLockedInHere().add(
            balanceSnapshot
            // AUTOFarm(autoFarmAddress).stakedWantTokens(poolId, address(this))
        );
    }

    function wantLockedInHere() override public view returns (uint256) {
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        return wantBal;
    }

    function setbuyBackRate(uint256 _buyBackRate) override public {
        require(msg.sender == govAddress, "Not authorised");
        require(buyBackRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
    }

    function setGov(address _govAddress) override public {
        require(msg.sender == govAddress, "Not authorised");
        govAddress = _govAddress;
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) override public {
        require(msg.sender == govAddress, "!gov");
        require(_token != autoAddress, "!safe");
        require(_token != wantAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }

    receive() external payable {}
}
