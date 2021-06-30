pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface IMasterBELT {
    function ownerBELTReward() external returns (uint256);
    function BELT() external returns (address);
}

interface ICompensationPool {
    function addFund(uint256 amount) external;
}

contract BELTTeamAllocationYieldStorage {
    address public masterBELTAddress;
    address public BELTAddress;
    address public BELTSupplierAddress;
    address public compensationPoolAddress;
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public ratioNumer;
    uint256 public ratioDenom;

    uint256 public lastYield;

    uint256 public constant unlocked = 30;

    uint256 public constant blocksPerYear = 60 * 60 * 24 * 365 / 3;
}

contract BELTTeamAllocationYield is Initializable, OwnableUpgradeable, BELTTeamAllocationYieldStorage {
    using SafeMathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    event BeltYielded(uint256 amount, uint256 indexed prevBlock, uint256 indexed curBlock);

    function __BELTTeamAllocationYield_init() public initializer {
        __Ownable_init();
        __BELTTeamAllocationYield_init_unchained();
    }

    function __BELTTeamAllocationYield_init_unchained() internal initializer {
        masterBELTAddress = 0xD4BbC80b9B102b77B21A06cb77E954049605E6c1;
        BELTAddress = IMasterBELT(masterBELTAddress).BELT();
        BELTSupplierAddress = 0x7111D0F651A331BC2b9eeFCFE56D8A03F92601a1;
        compensationPoolAddress = 0x820512F47Ba0a6b225288F5fa11cB9D8b65440b1;
        
        // mining starts on June 24th at 3pm in KST
        startBlock = 8568170;
        endBlock = startBlock.add(blocksPerYear);

        ratioNumer = 2;
        ratioDenom = 3;
        lastYield = startBlock;
        IERC20(BELTAddress).safeApprove(compensationPoolAddress, uint256(-1));
    }

    function yieldBelt() public {
        require(block.number > lastYield);
        require(lastYield < endBlock);
        uint256 blocksElapsed;
        if (block.number <= endBlock) {
            blocksElapsed = block.number.sub(lastYield);
            lastYield = block.number;
        } else {
            blocksElapsed = endBlock.sub(lastYield);
            lastYield = endBlock;
        }

        uint256 allocationPerBlock = IMasterBELT(masterBELTAddress).ownerBELTReward();
    
        uint256 yieldAmount = blocksElapsed.mul(1e18).mul(allocationPerBlock).mul(ratioNumer).mul(unlocked);
        yieldAmount = yieldAmount.div(1000).div(ratioDenom).div(100);
        IERC20(BELTAddress).safeTransferFrom(BELTSupplierAddress, address(this), yieldAmount);
        ICompensationPool(compensationPoolAddress).addFund(yieldAmount);

        emit BeltYielded(yieldAmount, lastYield.sub(blocksElapsed), lastYield);
    }
}