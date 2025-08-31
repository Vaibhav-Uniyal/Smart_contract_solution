# TradeEscrow Smart Contract

A Solidity smart contract for trade finance escrow with document verification and dispute resolution.

## Features

- **Escrow Management**: Secure holding of funds until trade completion
- **Document Verification**: Hash-based document verification by trusted third parties
- **State Management**: Clear trade states from creation to completion
- **Dispute Resolution**: Trusted verifier can resolve disputes between parties
- **Emergency Refunds**: Automatic refunds after 30 days if no progress
- **Withdrawal Pattern**: Safe fund withdrawal mechanism

## Contract States

1. **Created**: Initial state (not used in current implementation)
2. **PaymentHeld**: Buyer has deposited payment
3. **Shipped**: Seller has marked goods as shipped
4. **Delivered**: Buyer has confirmed delivery
5. **Released**: Payment released to seller
6. **Refunded**: Payment refunded to buyer
7. **Disputed**: Trade is under dispute

## Setup and Installation

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Compile the contract**:
   ```bash
   npm run compile
   ```

3. **Run tests**:
   ```bash
   npm test
   ```

4. **Start local blockchain**:
   ```bash
   npm run node
   ```

5. **Deploy to local network**:
   ```bash
   npm run deploy-local
   ```

## Usage

### Creating a Trade

```javascript
// Buyer creates a trade by sending payment
await tradeEscrow.createTrade(
  sellerAddress,
  verifierAddress,
  "Electronics shipment from A to B",
  { value: ethers.parseEther("1.0") }
);
```

### Document Flow

```javascript
// 1. Seller submits document hash
const docHash = ethers.keccak256(ethers.toUtf8Bytes("Bill of Lading content"));
await tradeEscrow.connect(seller).submitDocuments(tradeId, docHash);

// 2. Verifier verifies documents
await tradeEscrow.connect(verifier).verifyDocuments(tradeId);

// 3. Seller marks as shipped
await tradeEscrow.connect(seller).markShipped(tradeId);
```

### Completing Trade

```javascript
// Buyer confirms delivery (automatically releases payment)
await tradeEscrow.connect(buyer).confirmDelivery(tradeId);

// Seller withdraws funds
await tradeEscrow.connect(seller).withdraw();
```

### Dispute Resolution

```javascript
// Either party can raise a dispute
await tradeEscrow.connect(buyer).raiseDispute(tradeId);

// Verifier resolves dispute
await tradeEscrow.connect(verifier).resolveDispute(
  tradeId, 
  true, // true = refund buyer, false = pay seller
  "Reason for resolution"
);
```

## Key Functions

- `createTrade()`: Create new escrow trade
- `submitDocuments()`: Submit trade document hash
- `verifyDocuments()`: Verify submitted documents
- `markShipped()`: Mark goods as shipped
- `confirmDelivery()`: Confirm delivery and release payment
- `raiseDispute()`: Raise a dispute
- `resolveDispute()`: Resolve dispute (verifier only)
- `withdraw()`: Withdraw pending funds
- `emergencyRefund()`: Emergency refund after 30 days

## Security Features

- **Role-based access control**: Different permissions for buyer, seller, and verifier
- **State validation**: Functions only work in appropriate states
- **Withdrawal pattern**: Prevents reentrancy attacks
- **Emergency mechanisms**: Time-based emergency refunds
- **Input validation**: Comprehensive parameter validation

## Testing

The contract includes comprehensive tests covering:
- Contract deployment
- Trade creation and validation
- Document submission and verification
- Shipping and delivery flow
- Payment release and withdrawals
- Dispute raising and resolution
- Emergency refund mechanisms
- Error conditions and edge cases

Run tests with:
```bash
npm test
```

## Deployment

### Local Development
```bash
# Start local blockchain
npm run node

# Deploy to local network
npm run deploy-local
```

### Testnet Deployment
```bash
# Set environment variables
export SEPOLIA_URL="your-sepolia-rpc-url"
export PRIVATE_KEY="your-private-key"

# Deploy to Sepolia testnet
npm run deploy-sepolia
```

## License

MIT License
