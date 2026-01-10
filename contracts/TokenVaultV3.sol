// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenVaultV3
 * @dev Advanced vault with time-locked withdrawals and emergency mechanisms
 */
contract TokenVaultV3 is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // V1 & V2 variables
    IERC20 public token;
    uint256 public depositFee;
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    
    uint256 public yieldRate;
    mapping(address => uint256) public lastYieldUpdate;
    mapping(address => uint256) public accumulatedYield;
    bool public pausedDeposits;
    
    // V3 additions
    uint256 public withdrawalDelay; // Delay in seconds (e.g., 7 days = 604800)
    
    struct WithdrawalRequest {
        uint256 amount;
        uint256 requestTime;
    }
    
    mapping(address => WithdrawalRequest) public withdrawalRequests;
    
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 requestTime);
    event WithdrawalExecuted(address indexed user, uint256 amount);
    event EmergencyWithdrawalExecuted(address indexed user, uint256 amount);
    
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
        withdrawalDelay = 7 days; // Default 7 days
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }
    
    function deposit(uint256 amount) external {
        require(!pausedDeposits, "Deposits are paused");
        require(amount > 0, "Amount must be positive");
        
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
    
    function requestWithdrawal(uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        _updateYield(msg.sender);
        
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: amount,
            requestTime: block.timestamp
        });
        
        emit WithdrawalRequested(msg.sender, amount, block.timestamp);
    }
    
    function executeWithdrawal() external {
        WithdrawalRequest memory request = withdrawalRequests[msg.sender];
        require(request.amount > 0, "No withdrawal request");
        require(
            block.timestamp >= request.requestTime + withdrawalDelay,
            "Withdrawal delay not met"
        );
        
        uint256 amount = request.amount;
        
        // Clear the request
        delete withdrawalRequests[msg.sender];
        
        // Update balances
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // Transfer tokens
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        emit WithdrawalExecuted(msg.sender, amount);
    }
    
    function emergencyWithdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");
        
        // Clear withdrawal request if any
        delete withdrawalRequests[msg.sender];
        
        // Update balances
        balances[msg.sender] = 0;
        totalDeposits -= amount;
        accumulatedYield[msg.sender] = 0; // Forfeit yield on emergency
        
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        emit EmergencyWithdrawalExecuted(msg.sender, amount);
    }
    
    function _updateYield(address user) internal {
        if (lastYieldUpdate[user] == 0) {
            lastYieldUpdate[user] = block.timestamp;
            return;
        }
        
        uint256 timePassed = block.timestamp - lastYieldUpdate[user];
        uint256 userBalance = balances[user];
        
        if (userBalance > 0 && timePassed > 0) {
            uint256 yield = (userBalance * yieldRate * timePassed) / (10000 * 365 days);
            accumulatedYield[user] += yield;
        }
        
        lastYieldUpdate[user] = block.timestamp;
    }
    
    function claimYield() external {
        _updateYield(msg.sender);
        uint256 yield = accumulatedYield[msg.sender];
        require(yield > 0, "No yield to claim");
        
        accumulatedYield[msg.sender] = 0;
        require(token.transfer(msg.sender, yield), "Yield transfer failed");
    }
    
    function setWithdrawalDelay(uint256 _delaySeconds) external onlyRole(DEFAULT_ADMIN_ROLE) {
        withdrawalDelay = _delaySeconds;
    }
    
    function getWithdrawalDelay() external view returns (uint256) {
        return withdrawalDelay;
    }
    
    function getWithdrawalRequest(address user) external view returns (uint256 amount, uint256 requestTime, bool ready) {
        WithdrawalRequest memory request = withdrawalRequests[user];
        return (
            request.amount,
            request.requestTime,
            block.timestamp >= request.requestTime + withdrawalDelay
        );
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
    
    function setYieldRate(uint256 _yieldRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_yieldRate <= 10000, "Rate too high");
        yieldRate = _yieldRate;
    }
    
    function pauseDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        pausedDeposits = true;
    }
    
    function unpauseDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        pausedDeposits = false;
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
        return "3.0.0";
    }
    
    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(UPGRADER_ROLE)
    override
    {}
    
    // Storage gap for future upgrades
    uint256[44] private __gap; // Reduced from 50 to account for V3 variables
}
