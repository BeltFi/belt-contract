pragma solidity 0.6.12;

import "../StrategyV2.sol";
import "./StrategyVoidV2Storage.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract StrategyVoidV2 is Initializable, StrategyV2, StrategyVoidV2Storage {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Deposit(address wantAddress, uint256 amountReceived, uint256 amountDeposited);
    event Withdraw(address wantAddress, uint256 amountRequested, uint256 amountWithdrawn);

    function __StrategyVoidV2_init(
        address _wantAddress
    ) public initializer {
        __StrategyV2_init(msg.sender, 0, 100);
        __StrategyVoidV2_init_unchained(
            _wantAddress
        );
    }

    function __StrategyVoidV2_init_unchained(
        address _wantAddress
    ) internal initializer {
        wantAddress = _wantAddress;
        buyBackRate = 0;
    }

    function deposit(uint256 _wantAmt)
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

        emit Deposit(wantAddress, _wantAmt, _wantAmt);

        return _wantAmt;
    }


    function earn() external whenNotPaused {
    }

    function withdraw(uint256 _wantAmt)
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        require(wantLockedTotal() >= _wantAmt);
        IERC20(wantAddress).safeTransfer(owner(), _wantAmt);
        emit Withdraw(wantAddress, _wantAmt, _wantAmt);
        return _wantAmt;
    }


    function _pause() override internal {
        super._pause();
    }

    function pause() external {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function _unpause() override internal {
        super._unpause();
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();
    }

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere();
    }

    function wantLockedInHere() public view returns (uint256) {
        uint256 wantBal = IERC20(wantAddress).balanceOf(address(this));
        return wantBal;
    }

    function setGov(address _govAddress) public {
        require(msg.sender == govAddress, "Not authorised");
        govAddress = _govAddress;
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != wantAddress, "!safe");

        IERC20(_token).safeTransfer(_to, _amount);
    }

    function getProxyAdmin() public view returns (address adm) {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            adm := sload(slot)
        }
    }

    function updateStrategy() public {
    }
}