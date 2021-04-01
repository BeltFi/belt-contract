// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Strategy.sol";
import "../defi/alphaHomora.sol";
import "../defi/pancake.sol";

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}


contract StrategyAlpha is Strategy {

    address public pancakeRouterAddress;

    address public constant wbnbAddress =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant alphaAddress =
    0xa1faa113cbE53436Df28FF0aEe54275c13B40975;
    
    //ibBNB
    address public constant bankAddress =
    0x3bB5f6285c312fc7E1877244103036ebBEda193d;
    address public constant distributor = 
    0x86FC56Eb6E7eF9439b89Dd5825F08A14460D46A1;

    address public wantAddress;
    address immutable public BELTAddress;

    // only updated when deposit / withdraw / earn is called
    uint256 public balanceSnapshot;

    address[] public ALPHAToWantPath;
    address[] public ALPHAToBELTPath;
    address[] public wantToBELTPath;
    // cake to BELT

    constructor(
        address _BELTAddress,
        address _pancakeRouterAddress,
        address[] memory _ALPHAToWantPath,
        address[] memory _ALPHAToBELTPath,
        address[] memory _wantToBETLPATH
    ) public {
        govAddress = msg.sender;
        BELTAddress = _BELTAddress;

        wantAddress = wbnbAddress;

        ALPHAToWantPath = _ALPHAToWantPath;
        ALPHAToBELTPath = _ALPHAToBELTPath;
        wantToBELTPath = _wantToBETLPATH;

        pancakeRouterAddress = _pancakeRouterAddress;

        IERC20(alphaAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
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
        
        _unwrapBNB(_wantAmt);

        uint before = _stakedWantTokens();
        Bank(bankAddress).deposit{value: _wantAmt}();
        uint diff = _stakedWantTokens().sub(before);

        balanceSnapshot = balanceSnapshot.add(diff);

        return diff;
    }

    function withdraw(uint256 _wantAmt)
        override
        public
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        _wantAmt = _wantAmt.mul(withdrawFeeDenom.sub(withdrawFeeNumer)).div(withdrawFeeDenom);

        uint256 wantBal = _stakedWantTokens();
        uint256 amount = _wantAmt.mul(IERC20(bankAddress).totalSupply()).div(Bank(bankAddress).totalBNB());      
        Bank(bankAddress).withdraw(amount);
        wantBal = wantBal.sub(_stakedWantTokens());

        _wrapBNB(wantBal);
        IERC20(wantAddress).safeTransfer(owner(), wantBal);
        
        balanceSnapshot = balanceSnapshot.sub(_wantAmt);

        return wantBal;
    }

    function _stakedWantTokens() public view returns (uint256) {
        IERC20 _token = IERC20(bankAddress);
        uint _totalBNB = Bank(bankAddress).totalBNB();
        return _token.balanceOf(address(this)).mul(_totalBNB).div(_token.totalSupply());
    }

    function earn() override external whenNotPaused {
        uint earnedAmt = ALPHAToken(alphaAddress).balanceOf(address(this));
        if(earnedAmt != 0) {
            earnedAmt = buyBack(earnedAmt);
        
            if (alphaAddress != wantAddress) {
                IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
                    earnedAmt,
                    0,
                    ALPHAToWantPath,
                    address(this),
                    now.add(600)
                );
            }
        }

        uint256 prevBalance = balanceSnapshot;
        uint256 currentBalance = _stakedWantTokens();

        if (prevBalance < currentBalance) {
            earnedAmt = currentBalance.sub(prevBalance);
            buyBackWant(earnedAmt);
        }

        earnedAmt = IERC20(wantAddress).balanceOf(address(this)); //wbnb
        if (earnedAmt != 0) {
            _unwrapBNB(earnedAmt);
            Bank(bankAddress).deposit{value: earnedAmt}();
        }

        balanceSnapshot = _stakedWantTokens();
        lastEarnBlock = block.number;
    }

    function buyBackWant(uint256 _earnedAmt) internal {
        if (buyBackRate != 0) {
            uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);
            uint256 curWantBal = address(this).balance;
            
            if(curWantBal < buyBackAmt) {
                uint amount = (buyBackAmt.sub(curWantBal)).mul(IERC20(bankAddress).totalSupply()).div(Bank(bankAddress).totalBNB());
                Bank(bankAddress).withdraw(amount);
                buyBackAmt = address(this).balance;
                _wrapBNB(buyBackAmt);
            }

            IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
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

        IPancakeRouter02(pancakeRouterAddress).swapExactTokensForTokens(
            buyBackAmt,
            0,
            ALPHAToBELTPath,
            address(this),
            now + 600
        );

        uint256 burnAmt = IERC20(BELTAddress).balanceOf(address(this));
        IERC20(BELTAddress).safeTransfer(buyBackAddress, burnAmt);

        return _earnedAmt.sub(buyBackAmt);
    }

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");

        _pause();

        IERC20(alphaAddress).safeApprove(pancakeRouterAddress, 0);
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, 0);
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();

        IERC20(alphaAddress).safeApprove(pancakeRouterAddress, uint256(-1));
        IERC20(wantAddress).safeApprove(pancakeRouterAddress, uint256(-1));
    }

    function wantLockedTotal() override public view returns (uint256) {
        return wantLockedInHere().add(balanceSnapshot);
    }

    function wantLockedInHere() override public view returns (uint256) {
        uint256 wantBal = IERC20(wbnbAddress).balanceOf(address(this));
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
        require(_token != alphaAddress, "!safe");
        require(_token != wantAddress, "!safe");
        require(_token != bankAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }
    
    function _wrapBNB(uint256 _amount) internal {
        if (address(this).balance >= _amount) {
            IWBNB(wbnbAddress).deposit{value: _amount}();
        }
    }

    function _unwrapBNB(uint256 _amount) internal {
        uint256 wbnbBal = IERC20(wbnbAddress).balanceOf(address(this));
        if (wbnbBal >= _amount) {
            IWBNB(wbnbAddress).withdraw(_amount);
        }
    }

    receive() external payable {}

}