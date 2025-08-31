# Complete Testing Guide for Assignment

## 🎯 Testing Scenarios for Screenshots

### **Scenario 1: Complete Successful Trade Flow**

#### **Setup Accounts (Use Different Remix Accounts):**
- **Account 0**: Buyer (0x5B38Da6a701c568545dCfcB03FcB875f56beddC4)
- **Account 1**: Seller (Copy from Remix account dropdown)
- **Account 2**: Verifier (Copy from Remix account dropdown)

#### **Step 1: Create Trade (Buyer)**
1. **Select Account 0** (Buyer)
2. **Set Value**: `1000000000000000000` (1 ETH)
3. **Call createTrade**:
   - **seller**: [Account 1 address]
   - **verifier**: [Account 2 address]
   - **shipmentDetails**: `"Electronics shipment from China to USA"`
4. **📸 Screenshot**: Transaction success + returned trade ID

#### **Step 2: Check Trade Details**
1. **Call getTrade(1)**
2. **📸 Screenshot**: All trade details showing PaymentHeld state

#### **Step 3: Submit Documents (Seller)**
1. **Switch to Account 1** (Seller)
2. **Generate document hash**:
   - **Call generateDocumentHash**: `"Bill of Lading BL-2024-001"`
   - **Copy the returned hash**
3. **Call submitDocuments**:
   - **tradeId**: `1`
   - **docHash**: [paste the hash]
4. **📸 Screenshot**: DocumentSubmitted event

#### **Step 4: Verify Documents (Verifier)**
1. **Switch to Account 2** (Verifier)
2. **Call verifyDocuments**:
   - **tradeId**: `1`
3. **📸 Screenshot**: DocumentVerified event

#### **Step 5: Mark as Shipped (Seller)**
1. **Switch to Account 1** (Seller)
2. **Call markShipped**:
   - **tradeId**: `1`
3. **📸 Screenshot**: MarkedShipped event + state change

#### **Step 6: Confirm Delivery (Buyer)**
1. **Switch to Account 0** (Buyer)
2. **Call confirmDelivery**:
   - **tradeId**: `1`
3. **📸 Screenshot**: DeliveryConfirmed + PaymentReleased events

#### **Step 7: Check Pending Withdrawal (Seller)**
1. **Call getPendingWithdrawal**: [Account 1 address]
2. **📸 Screenshot**: Shows 1 ETH pending

#### **Step 8: Withdraw Funds (Seller)**
1. **Switch to Account 1** (Seller)
2. **Call withdraw** (no parameters)
3. **📸 Screenshot**: Successful withdrawal + balance change

### **Scenario 2: Dispute Resolution**

#### **Step 1: Create New Trade**
1. **Repeat Steps 1-3 from Scenario 1** (use different shipment details)
2. **Trade ID should be 2**

#### **Step 2: Raise Dispute (Buyer)**
1. **Switch to Account 0** (Buyer)
2. **Call raiseDispute**:
   - **tradeId**: `2`
3. **📸 Screenshot**: DisputeRaised event

#### **Step 3: Resolve Dispute (Verifier)**
1. **Switch to Account 2** (Verifier)
2. **Call resolveDispute**:
   - **tradeId**: `2`
   - **refundToBuyer**: `true`
   - **reason**: `"Goods not as described"`
3. **📸 Screenshot**: DisputeResolved + Refunded events

#### **Step 4: Buyer Withdraws Refund**
1. **Switch to Account 0** (Buyer)
2. **Call withdraw**
3. **📸 Screenshot**: Successful refund withdrawal

### **Scenario 3: Contract State Verification**

#### **Additional Screenshots Needed:**
1. **📸 Contract Balance**: `getContractBalance()` showing 0 after withdrawals
2. **📸 Next Trade ID**: `nextTradeId` showing 3
3. **📸 Trade States**: `getTrade(1)` showing Released state
4. **📸 Trade States**: `getTrade(2)` showing Refunded state

## 📊 **Performance Metrics to Capture:**

1. **Gas Usage**: Note gas costs for each transaction
2. **Transaction Times**: Note block confirmations
3. **State Changes**: Document all state transitions
4. **Event Emissions**: Capture all emitted events

## 🔍 **Testing Checklist:**

- [ ] Trade creation with payment deposit
- [ ] Document submission and verification
- [ ] Shipment tracking (state changes)
- [ ] Automated payment release
- [ ] Dispute raising and resolution
- [ ] Emergency refund mechanism (optional)
- [ ] Withdrawal pattern functionality
- [ ] Access control (only authorized users can call functions)
- [ ] Error handling (invalid inputs)

## 📝 **Documentation for Each Screenshot:**

For each screenshot, note:
1. **Function called**
2. **Parameters used**
3. **Account used**
4. **Gas cost**
5. **Events emitted**
6. **State changes**
7. **Expected vs Actual results**
