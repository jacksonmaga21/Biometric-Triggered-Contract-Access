# 🔐 Biometric-Triggered Contract Access

> **Secure smart contract interactions using off-chain biometric verification oracles** 🧬

A Clarity smart contract that gates access to protected functions through biometric authentication provided by trusted oracles. Users must verify their biometric identity off-chain before executing sensitive contract operations.

## ✨ Features

- 🔒 **Biometric Access Control**: Gate contract functions behind biometric verification
- 🌐 **Oracle Network**: Decentralized network of trusted biometric verification oracles  
- ⏱️ **Time-Limited Verification**: Verifications expire after a configurable timeout
- 💰 **Fee-Based Protection**: Protected functions require payment for execution
- 📊 **Oracle Reputation System**: Track oracle performance and reliability
- 🛡️ **Admin Controls**: Owner can manage oracles, functions, and system settings

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd Biometric-Triggered-Contract-Access
clarinet check
```

## 📋 Contract Overview

### Core Components

1. **Oracle Management** 🏢
   - Register trusted biometric verification services
   - Track oracle reputation and performance metrics
   - Enable/disable oracles based on reliability

2. **Biometric Verification** 👁️
   - Submit off-chain biometric verification results
   - Time-limited verification tokens with nonce system
   - Secure mapping between users and verification status

3. **Protected Functions** 🛡️
   - Define functions requiring biometric authentication
   - Set reputation requirements and execution fees
   - Control access based on verification status

4. **User Fund Management** 💳
   - Deposit STX tokens for function execution fees
   - Withdraw unused funds
   - Track user balances and spending

## 🔧 Usage Instructions

### For Oracle Operators

1. **Register as Oracle** (Owner only)
```clarity
(contract-call? .biometric-triggered register-oracle)
```

2. **Submit Verification**
```clarity
(contract-call? .biometric-triggered submit-verification 
  'SP1234...USER-PRINCIPAL true u1)
```

### For Users

1. **Deposit Funds**
```clarity
(contract-call? .biometric-triggered deposit-funds u1000000)
```

2. **Get Biometric Verification** (Off-chain process)
   - Contact registered oracle for biometric scan
   - Oracle submits verification result to contract

3. **Execute Protected Function**
```clarity
(contract-call? .biometric-triggered verify-and-execute u1)
```

### For Contract Owner

1. **Add Protected Function**
```clarity
(contract-call? .biometric-triggered add-protected-function 
  u1 "sensitive-operation" u75 u100000)
```

2. **Update Oracle Reputation**
```clarity
(contract-call? .biometric-triggered update-oracle-reputation 
  'SP5678...ORACLE-PRINCIPAL u90)
```

## 📊 Read-Only Functions

Query contract state without transactions:

```clarity
;; Get oracle information
(contract-call? .biometric-triggered get-oracle-info 'SP5678...ORACLE)

;; Check verification status  
(contract-call? .biometric-triggered get-verification 'SP1234...USER u1)

;; View user balance
(contract-call? .biometric-triggered get-user-balance 'SP1234...USER)

;; Get contract statistics
(contract-call? .biometric-triggered get-contract-stats)
```

## 🔐 Security Features

- **Oracle Reputation**: Minimum reputation requirements prevent malicious verification
- **Time Expiration**: Verifications automatically expire to prevent replay attacks  
- **Nonce System**: Sequential nonces prevent verification reuse
- **Fee Protection**: Financial cost deters spam and abuse
- **Owner Controls**: Administrative functions for system management

## ⚙️ Configuration

### Default Settings

- **Verification Timeout**: 144 blocks (~24 hours)
- **Minimum Oracle Reputation**: 50/100
- **Initial Oracle Reputation**: 100/100

### Adjustable Parameters

- Verification timeout duration
- Oracle reputation scores
- Protected function fees and requirements
- Contract enable/disable state

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

Example test scenarios:
- Oracle registration and verification submission
- User fund management and withdrawals
- Protected function access control
- Verification expiration and nonce handling

## 🔄 Workflow Example

1. **Setup Phase** 🎯
   - Owner deploys contract
   - Owner registers trusted biometric oracles
   - Owner defines protected functions with requirements

2. **User Onboarding** 👤
   - User deposits STX for transaction fees
   - User completes off-chain biometric enrollment

3. **Verification Process** ✅
   - User requests biometric verification from oracle
   - Oracle performs biometric check off-chain
   - Oracle submits verification result to contract

4. **Protected Access** 🚪
   - User calls verify-and-execute with function ID
   - Contract validates verification status and requirements
   - Function executes if all conditions met

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙋‍♀️ Support

For questions and support:
- Create an issue in this repository
- Check existing documentation and examples
- Review test files for usage patterns

---

**Built with ❤️ using Clarity and Stacks blockchain** 🟠
