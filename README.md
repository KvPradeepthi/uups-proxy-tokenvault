# UUPS Proxy TokenVault - Production-Grade Upgradeable Smart Contract System

## Overview

This repository contains a production-grade implementation of an upgradeable token vault system using the UUPS (Universal Upgradeable Proxy Standard) pattern. The system demonstrates how to build secure, upgradeable smart contracts that follow industry best practices.

## Project Structure

```
uups-proxy-tokenvault/
├── contracts/
│   ├── TokenVaultV1.sol       # Base contract: deposit/withdrawal with fees
│   ├── TokenVaultV2.sol       # Adds yield generation and pause controls
│   ├── TokenVaultV3.sol       # Adds withdrawal delays and emergency mechanisms
│   └── mocks/
│       └── MockERC20.sol      # Test ERC20 token
├── test/
│   ├── TokenVaultV1.test.js   # V1 functionality tests
│   ├── upgrade-v1-to-v2.test.js # V1→V2 upgrade tests
│   ├── upgrade-v2-to-v3.test.js # V2→V3 upgrade tests
│   └── security.test.js        # Security validation tests
├── scripts/
│   ├── deploy-v1.js           # Deploy V1 proxy and implementation
│   ├── upgrade-to-v2.js       # Upgrade proxy to V2
│   └── upgrade-to-v3.js       # Upgrade proxy to V3
├── hardhat.config.js          # Hardhat configuration
├── package.json               # Project dependencies
└── README.md                  # This file
```

## Features

### TokenVaultV1
- **Deposit tokens** with automatic fee deduction
- **Withdraw funds** with balance validation
- **Role-based access control** using OpenZeppelin AccessControl
- **UUPS proxy pattern** for upgradeable contracts
- **Storage gaps** for future upgrade compatibility

### TokenVaultV2 (Upgradable)
- **Yield generation** with configurable annual rates
- **Yield claiming** with per-user tracking
- **Pause mechanism** for emergency situations
- **State preservation** during upgrade from V1
- **Backward compatible** with all V1 functions

### TokenVaultV3 (Upgradable)
- **Withdrawal delays** with time-locked execution
- **Withdrawal requests** instead of direct withdrawals
- **Emergency withdrawals** to bypass delays
- **Multi-version state preservation**
- **Complete backward compatibility**

## Getting Started

### Installation

```bash
npm install
```

### Running Tests

```bash
npx hardhat test
```

### Deploying V1

```bash
npx hardhat run scripts/deploy-v1.js --network sepolia
```

### Upgrading to V2

```bash
npx hardhat run scripts/upgrade-to-v2.js --network sepolia
```

### Upgrading to V3

```bash
npx hardhat run scripts/upgrade-to-v3.js --network sepolia
```

## Key Implementation Details

### Storage Layout Management
- Uses explicit storage gaps (`uint256[50] private __gap`) to reserve space for future variables
- Gaps are reduced as new variables are added in upgraded versions
- Prevents storage collisions between implementation versions

### Initialization Security
- Uses `@openzeppelin/contracts-upgradeable` for safe initializer patterns
- Implements `_disableInitializers()` in constructor to prevent direct initialization
- Single-use `initializer` modifier prevents re-initialization attacks

### Access Control
- `DEFAULT_ADMIN_ROLE`: Full administrative permissions
- `UPGRADER_ROLE`: Exclusive upgrade permissions
- Roles can be granted/revoked through OpenZeppelin's AccessControl

### Proxy Pattern (UUPS)
- Implementation contracts inherit from `UUPSUpgradeable`
- `_authorizeUpgrade()` function validates upgrade authorization
- Upgrade logic is in the implementation, not the proxy
- Reduces proxy size and improves gas efficiency

## Security Considerations

1. **No Constructor Logic**: Implementation contracts use `initialize()` instead of constructors
2. **Storage Consistency**: All variables maintain their order and type across versions
3. **Access Control**: Upgrades are restricted to authorized roles
4. **Gap Management**: Future variables won't collide with existing storage
5. **Event Logging**: All critical operations emit events for transparency
6. **Reentrancy Safety**: Uses checks-effects-interactions pattern

## Testing

The project includes comprehensive test suites:
- **Unit tests**: Individual function behavior
- **Integration tests**: Multi-function workflows
- **Upgrade tests**: State preservation during upgrades
- **Security tests**: Attack vectors and edge cases
- **Compatibility tests**: Cross-version interaction

## Dependencies

```json
{
  "@openzeppelin/contracts": "^5.0.0",
  "@openzeppelin/contracts-upgradeable": "^5.0.0",
  "@openzeppelin/hardhat-upgrades": "^2.0.0",
  "hardhat": "^2.19.0",
  "chai": "^4.3.7",
  "ethers": "^6.7.0"
}
```

## Functions Reference

### TokenVaultV1
- `initialize(address _token, address _admin, uint256 _depositFee)` - Initialize proxy
- `deposit(uint256 amount)` - Deposit tokens with fee
- `withdraw(uint256 amount)` - Withdraw tokens
- `balanceOf(address user)` - Get user balance
- `totalDeposits()` - Get total vault deposits
- `getDepositFee()` - Get current deposit fee
- `getImplementationVersion()` - Get contract version

### TokenVaultV2 (Additional)
- `setYieldRate(uint256 _yieldRate)` - Set annual yield rate
- `claimYield()` - Claim accrued yield
- `getUserYield(address user)` - Get pending yield
- `pauseDeposits()` - Pause new deposits
- `unpauseDeposits()` - Resume deposits
- `isDepositsPaused()` - Check pause status

### TokenVaultV3 (Additional)
- `requestWithdrawal(uint256 amount)` - Request time-locked withdrawal
- `executeWithdrawal()` - Execute requested withdrawal
- `getWithdrawalRequest(address user)` - Get pending withdrawal
- `setWithdrawalDelay(uint256 _delaySeconds)` - Set delay duration
- `getWithdrawalDelay()` - Get current delay
- `emergencyWithdraw()` - Immediate withdrawal

## License

MIT

## Author

Kamichetty Veera Pradeepthi
