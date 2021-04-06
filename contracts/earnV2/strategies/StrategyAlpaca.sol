pragma solidity 0.6.12;

import "./Strategy.sol";
import "../defi/alpaca.sol";
import "../defi/pancake.sol";

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

contract StrategyAlpaca is Strategy {

    address public uniRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant alpacaAddress =
    0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F;
    address public constant fairLaunchAddress =
    0xA625AB01B08ce023B2a342Dbb12a16f2C8489A8F;

    bool public immutable isWbnb;

    address public vaultAddress;
    address public wantAddress;
    address immutable public BELTAddress;

    // only updated when deposit / withdraw / earn is called
    uint256 public balanceSnapshot;

    // 1 = WBNB, 3 = BUSD
    uint256 public immutable poolId;

    address[] public alpacaToWantPath;
    address[] public alpacaToBELTPath;
    address[] public wantToBELTPath;

    constructor(
        address _vaultAddress,
        address _BELTAddress,
        address _wantAddress,
        address _uniRouterAddress,
        uint256 _poolId,
        address[] memory _alpacaToWantPath,
        address[] memory _alpacaToBELTPath,
        address[] memory _wantToBETLPATH
    ) public {
        govAddress = msg.sender;

        vaultAddress = _vaultAddress;
        wantAddress = _wantAddress;
        BELTAddress = _BELTAddress;

        poolId = _poolId;
        isWbnb = _wantAddress == wbnbAddress;

        alpacaToWantPath = _alpacaToWantPath;
        alpacaToBELTPath = _alpacaToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        uniRouterAddress = _uniRouterAddress;

        IERC20(alpacaAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(_wantAddress).safeApprove(vaultAddress, uint256(-1));
        IERC20(vaultAddress).safeApprove(fairLaunchAddress, uint256(-1));
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

        uint256 before = _stakedWantTokens();
        _deposit(_wantAmt);
        uint256 diff = _stakedWantTokens().sub(before);

        balanceSnapshot = balanceSnapshot.add(diff);

        return diff;
    }

    function _deposit(uint _wantAmt) internal {
        if(isWbnb) {
            _unwrapBNB();
            Vault(vaultAddress).deposit{value: _wantAmt}(_wantAmt);
        } else {
            Vault(vaultAddress).deposit(_wantAmt);
        }
        FairLaunch(fairLaunchAddress).deposit(address(this), poolId, Vault(vaultAddress).balanceOf(address(this)));
    }

    function earn() override external whenNotPaused {
        FairLaunch(fairLaunchAddress).harvest(poolId);

        uint256 earnedAmt = AlpacaToken(alpacaAddress).balanceOf(address(this));
        earnedAmt = buyBack(earnedAmt);

        if (alpacaAddress != wantAddress) {
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokens(
                earnedAmt,
                0,
                alpacaToWantPath,
                address(this),
                now.add(600)
            );
        }

        uint256 prevBalance = balanceSnapshot;
        uint256 currentBalance = _stakedWantTokens();

        if (currentBalance > prevBalance) {
            earnedAmt = currentBalance.sub(prevBalance);
            buyBackWant(earnedAmt);
        }

        earnedAmt = IERC20(wantAddress).balanceOf(address(this));
        if (earnedAmt != 0) {
            _deposit(earnedAmt);
        }
        balanceSnapshot = _stakedWantTokens();
        
        lastEarnBlock = block.number;
    }

    function buyBackWant(uint256 _earnedAmt) internal {
        if (buyBackRate != 0) {
            uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);

            if(isWbnb) {
                _wrapBNB();
            }

            uint256 curWantBal = IERC20(wantAddress).balanceOf(address(this));

            if (curWantBal < buyBackAmt) {
                _withdraw(buyBackAmt.sub(curWantBal));
                if(isWbnb) {
                    _wrapBNB();
                }
                buyBackAmt = IERC20(wantAddress).balanceOf(address(this));
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
            alpacaToBELTPath,
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
        
        uint wantBal;
        uint256 lockedAmt = wantLockedInHere();
        uint256 diff = _stakedWantTokens();

        if(_wantAmt > wantLockedInHere()) {
            _withdraw(_wantAmt.sub(
                wantLockedInHere()
            ));
            diff = diff.sub(
                _stakedWantTokens()
            );
            wantBal = lockedAmt.add(diff);
        } else {
            wantBal = _wantAmt;
        }

        if(isWbnb) {
            _wrapBNB();
        }

        IERC20(wantAddress).safeTransfer(owner(), wantBal);

        balanceSnapshot = balanceSnapshot.sub(diff);

        return wantBal;
    }

    function _withdraw(uint256 _wantAmt) internal {
        uint256 amount = _wantAmt.mul(Vault(vaultAddress).totalSupply()).div(Vault(vaultAddress).totalToken());
        FairLaunch(fairLaunchAddress).withdraw(address(this), poolId, amount);
        Vault(vaultAddress).withdraw(Vault(vaultAddress).balanceOf(address(this)));
    }

    function _stakedWantTokens() public view returns (uint256) {
        (uint256 _amount, , ,) = FairLaunch(fairLaunchAddress).userInfo(poolId, address(this));
        return _amount.mul(Vault(vaultAddress).totalToken()).div(Vault(vaultAddress).totalSupply());
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");

        _pause();

        IERC20(alpacaAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(uniRouterAddress, 0);
        IERC20(wantAddress).safeApprove(vaultAddress, 0);
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();

        IERC20(alpacaAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(vaultAddress, uint256(-1));
    }

    function wantLockedTotal() override public view returns (uint256) {
        return wantLockedInHere().add(
            balanceSnapshot
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
        require(_token != alpacaAddress, "!safe");
        require(_token != wantAddress, "!safe");
        require(_token != vaultAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _wrapBNB() internal {
        uint256 bnbBal = address(this).balance;
        if (bnbBal > 0) {
            IWBNB(wbnbAddress).deposit{value: bnbBal}();
        }
    }

    function _unwrapBNB() internal {
        uint256 wbnbBal = IERC20(wbnbAddress).balanceOf(address(this));
        if (wbnbBal > 0) {
            IWBNB(wbnbAddress).withdraw(wbnbBal);
        }
    }

    receive() external payable {}
}
