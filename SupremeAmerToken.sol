// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin Contracts (Install via npm or import via Remix)
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SupremeAmerToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 100_000_000_000 * 1e18;
    uint256 public constant FEE_PERCENT = 6;
    uint256 public constant STAKING_YIELD = 22; // Represented as 2.2% (22/1000)
    uint256 public constant STAKING_DENOMINATOR = 1000;
    uint256 public constant SECONDS_IN_YEAR = 31536000;

    address public feeRecipient;
    mapping(address => bool) public isAffiliate;
    string public logoURI;

    // Staking
    struct StakeInfo {
        uint256 amount;
        uint256 since;
        uint256 rewardDebt;
    }

    mapping(address => StakeInfo) public stakes;

    event FeeRecipientChanged(address indexed newRecipient);
    event AffiliateAdded(address indexed affiliate);
    event AffiliateRemoved(address indexed affiliate);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event Burn(address indexed from, uint256 amount);
    event LogoChanged(string newLogo);

    constructor(address _feeRecipient, string memory _logoURI) ERC20("SupremeAmer", "SA") {
        feeRecipient = _feeRecipient;
        logoURI = _logoURI;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // Override transfer to apply fee
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        // No fee for owner or feeRecipient, or internal transfers
        if (sender == owner() || recipient == owner() || sender == feeRecipient || recipient == feeRecipient) {
            super._transfer(sender, recipient, amount);
        } else {
            uint256 fee = (amount * FEE_PERCENT) / 100;
            uint256 afterFee = amount - fee;
            // Send fee to feeRecipient
            super._transfer(sender, feeRecipient, fee);
            super._transfer(sender, recipient, afterFee);
        }
    }

    // Minting (for mining or other authorized purposes)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Burning (holder can burn their tokens)
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    // Staking
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        _transfer(msg.sender, address(this), amount);
        _updateReward(msg.sender);
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].since = block.timestamp;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(stakes[msg.sender].amount >= amount, "Not enough staked");
        _updateReward(msg.sender);
        uint256 reward = stakes[msg.sender].rewardDebt;
        stakes[msg.sender].rewardDebt = 0;
        stakes[msg.sender].amount -= amount;
        _transfer(address(this), msg.sender, amount + reward);
        emit Unstaked(msg.sender, amount, reward);
    }

    // Calculate and update staking rewards
    function _updateReward(address staker) internal {
        StakeInfo storage info = stakes[staker];
        if (info.amount > 0) {
            uint256 timeDiff = block.timestamp - info.since;
            uint256 reward = (info.amount * STAKING_YIELD * timeDiff) / (STAKING_DENOMINATOR * SECONDS_IN_YEAR);
            info.rewardDebt += reward;
        }
        info.since = block.timestamp;
    }

    function pendingReward(address staker) public view returns (uint256) {
        StakeInfo storage info = stakes[staker];
        if (info.amount == 0) return info.rewardDebt;
        uint256 timeDiff = block.timestamp - info.since;
        uint256 reward = (info.amount * STAKING_YIELD * timeDiff) / (STAKING_DENOMINATOR * SECONDS_IN_YEAR);
        return info.rewardDebt + reward;
    }

    // Affiliate management
    function addAffiliate(address affiliate) external onlyOwner {
        isAffiliate[affiliate] = true;
        emit AffiliateAdded(affiliate);
    }

    function removeAffiliate(address affiliate) external onlyOwner {
        isAffiliate[affiliate] = false;
        emit AffiliateRemoved(affiliate);
    }

    // Fee recipient management
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Zero address");
        feeRecipient = _feeRecipient;
        emit FeeRecipientChanged(_feeRecipient);
    }

    // Logo management
    function setLogoURI(string memory _logoURI) external onlyOwner {
        logoURI = _logoURI;
        emit LogoChanged(_logoURI);
    }
}
