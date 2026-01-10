// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenVaultV2
 * @dev Enhanced vault with yield generation and pause controls
 */
contract TokenVaultV2 is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    IERC20 public token;
    uint256 public depositFee;
    
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    
    // V2 additions
    uint256 public yieldRate; // Annual yield rate in basis points (100 = 1%)
    mapping(address => uint256) public lastYieldUpdate;
    mapping(address => uint256) public accumulatedYield;
    bool public pausedDeposits;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _token, address _admin, uint256 _depositFee) 
    external 
    initializer 
    {
        require(_token != address(0), "Invalid token");
        require(_depositFee <= 10000, "Fee too high");
        
        token = IERC20(_token);
        depositFee = _depositFee;
        yieldRate = 500; // Default 5% annual yield
        pausedDeposits = false;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }
    
    function deposit(uint256 amount) external {
        require(!pausedDeposits, "Deposits are paused");
        require(amount > 0, "Amount must be positive");
        
        // Claim yield before depositing
        _updateYield(msg.sender);
        
        uint256 fee = (amount * depositFee) / 10000;
        uint256 depositAmount = amount - fee;
        
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        balances[msg.sender] += depositAmount;
        totalDeposits += depositAmount;
    }
    
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        // Claim yield before withdrawing
        _updateYield(msg.sender);
        
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }
    
    function _updateYield(address user) internal {
        if (lastYieldUpdate[user] == 0) {
            lastYieldUpdate[user] = block.timestamp;
            return;
        }
        
        uint256 timePassed = block.timestamp - lastYieldUpdate[user];
        uint256 userBalance = balances[user];
        
        if (userBalance > 0 && timePassed > 0) {
            // Calculate yield: balance * rate * time / (10000 * 365 days)
            uint256 yield = (userBalance * yieldRate * timePassed) / (10000 * 365 days);
            accumulatedYield[user] += yield;
        }
        
        lastYieldUpdate[user] = block.timestamp;
    }
    
    function setYieldRate(uint256 _yieldRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_yieldRate <= 10000, "Rate too high");
        yieldRate = _yieldRate;
    }
    
    function claimYield() external {
        _updateYield(msg.sender);
        uint256 yield = accumulatedYield[msg.sender];
        require(yield > 0, "No yield to claim");
        
        accumulatedYield[msg.sender] = 0;
        require(token.transfer(msg.sender, yield), "Yield transfer failed");
    }
    
    function getUserYield(address user) external view returns (uint256) {
        if (lastYieldUpdate[user] == 0) return accumulatedYield[user];
        
        uint256 timePassed = block.timestamp - lastYieldUpdate[user];
        uint256 userBalance = balances[user];
        uint256 pendingYield = 0;
        
        if (userBalance > 0 && timePassed > 0) {
            pendingYield = (userBalance * yieldRate * timePassed) / (10000 * 365 days);
        }
        
        return accumulatedYield[user] + pendingYield;
    }
    
    function pauseDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        pausedDeposits = true;
    }
    
    function unpauseDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        pausedDeposits = false;
    }
    
    function isDepositsPaused() external view returns (bool) {
        return pausedDeposits;
    }
    
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
    
    function totalDeposits_() external view returns (uint256) {
        return totalDeposits;
    }
    
    function getDepositFee() external view returns (uint256) {
        return depositFee;
    }
    
    function getImplementationVersion() external pure returns (string memory) {
        return "2.0.0";
    }
    
    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(UPGRADER_ROLE)
    override
    {}
    
    // Storage gap for future upgrades
    uint256[47] private __gap; // Reduced from 50 to account for new V2 variables
}
