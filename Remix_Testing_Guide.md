# Testing TradeEscrow in Remix IDE

## Step-by-Step Testing Guide

### 1. Setup in Remix

1. Go to [Remix IDE](https://remix.ethereum.org/)
2. Create a new file called `TradeEscrow.sol`
3. Copy and paste the content from `TradeEscrow_Remix.sol`
4. Compile the contract (Ctrl+S or use the Solidity Compiler tab)

### 2. Deploy the Contract

1. Go to the "Deploy & Run Transactions" tab
2. Select "Remix VM (London)" as the environment (for testing)
3. Make sure "TradeEscrow" is selected in the contract dropdown
4. Click "Deploy"

### 3. Test Scenario: Complete Trade Flow

#### Setup Test Accounts
Remix provides multiple test accounts. Use them as:
- **Account 0**: Buyer
- **Account 1**: Seller  
- **Account 2**: Verifier

#### Step 1: Create a Trade (as Buyer)
```
1. Select Account 0 (Buyer)
2. Set Value to 1000000000000000000 wei (1 ETH) in the "Value" field
3. Call createTrade with parameters:
   - seller: [Account 1 address]
   - verifier: [Account 2 address]  
   - shipmentDetails: "Electronics from A to B"
4. Click "transact"
```

#### Step 2: Submit Documents (as Seller)
```
1. Switch to Account 1 (Seller)
2. First, generate a document hash:
   - Call generateDocumentHash("Bill of Lading XYZ123")
   - Copy the returned hash
3. Call submitDocuments:
   - tradeId: 1
   - docHash: [paste the hash from step 2]
```

#### Step 3: Verify Documents (as Verifier)
```
1. Switch to Account 2 (Verifier)
2. Call verifyDocuments:
   - tradeId: 1
```

#### Step 4: Mark as Shipped (as Seller)
```
1. Switch to Account 1 (Seller)
2. Call markShipped:
   - tradeId: 1
```

#### Step 5: Confirm Delivery (as Buyer)
```
1. Switch to Account 0 (Buyer)
2. Call confirmDelivery:
   - tradeId: 1
```

#### Step 6: Withdraw Funds (as Seller)
```
1. Switch to Account 1 (Seller)
2. Call withdraw (no parameters)
3. Check the seller's balance - it should have increased by ~1 ETH (minus gas)
```

### 4. Test Other Scenarios

#### Dispute Resolution
```
1. Create a new trade (repeat Step 1 with different value)
2. As buyer or seller, call raiseDispute with tradeId: 2
3. As verifier, call resolveDispute:
   - tradeId: 2
   - refundToBuyer: true (or false)
   - reason: "Goods not as described"
4. The appropriate party can then withdraw funds
```

#### Emergency Refund Testing
```
Note: In Remix VM, you can't easily fast-forward time, 
so emergency refund testing is limited. The function is there
but requires 30 days to pass.
```

### 5. Useful View Functions for Testing

- `getTrade(tradeId)`: Get all trade details
- `getPendingWithdrawal(address)`: Check pending withdrawal amount
- `getContractBalance()`: Check contract's total balance
- `getCurrentTimestamp()`: Get current block timestamp

### 6. Expected Results

After a successful complete trade flow:
- Trade state should be "4" (Released)
- Seller should have pending withdrawal equal to the trade value
- Contract balance should equal total pending withdrawals
- After withdrawal, seller's account balance increases

### 7. Common Issues and Solutions

**Issue**: "Only buyer allowed" error
**Solution**: Make sure you're using the correct account that created the trade

**Issue**: "Invalid state for this action"  
**Solution**: Check the trade state with `getTrade()` and ensure you're following the correct sequence

**Issue**: "No documents submitted"
**Solution**: Seller must submit documents before verifier can verify them

**Issue**: "Documents must be verified first"
**Solution**: Verifier must verify documents before seller can mark as shipped

### 8. State Transitions

```
PaymentHeld (1) → [documents submitted] → PaymentHeld (1)
PaymentHeld (1) → [documents verified] → PaymentHeld (1)  
PaymentHeld (1) → [marked shipped] → Shipped (2)
Shipped (2) → [delivery confirmed] → Delivered (3) → Released (4)
PaymentHeld (1) or Shipped (2) → [dispute raised] → Disputed (6)
Disputed (6) → [dispute resolved] → Released (4) or Refunded (5)
```

### 9. Testing Events

In Remix, you can see emitted events in the transaction details:
- Look for "logs" section after each transaction
- Events help track the contract's behavior
- Useful for debugging and verification

This contract is fully functional in Remix IDE and includes all the features from the original design plus additional helper functions for testing!
