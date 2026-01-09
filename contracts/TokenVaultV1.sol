// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenVaultV1
 * @dev Basic vault for depositing and withdrawing ERC20 tokens with deposit fee
 */
contract TokenVaultV1 is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    IERC20 public token;
    uint256 public depositFee;
    
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;

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
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        
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
        
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        
        require(token.transfer(msg.sender, amount), "Transfer failed");
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
        return "1.0.0";
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    // Storage gap for future upgrades
    uint256[50] private __gap;
}
