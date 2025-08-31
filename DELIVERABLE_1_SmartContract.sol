// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TradeEscrow - Blockchain Trade Finance Solution
 * @notice Complete smart contract for international trade finance with automated escrow,
 *         document verification, shipment tracking, automated payments, and dispute resolution
 * @author [Your Name]
 * @dev This contract implements all 5 core requirements for the blockchain assignment:
 *      1. Transaction Initiation with payment deposit
 *      2. Document Verification through cryptographic hashing
 *      3. Shipment Tracking via state machine
 *      4. Automated Payment release upon delivery confirmation
 *      5. Dispute Resolution through trusted third parties
 */
contract TradeEscrow {
    
    // ==================== STATE VARIABLES ====================
    
    /**
     * @dev Enum representing the various states a trade can be in
     * Created: Initial state (unused in current implementation)
     * PaymentHeld: Buyer has deposited payment, awaiting document verification
     * Shipped: Goods have been shipped after document verification
     * Delivered: Buyer has confirmed delivery of goods
     * Released: Payment has been released to seller
     * Refunded: Payment has been refunded to buyer
     * Disputed: Trade is under dispute resolution
     */
    enum State { Created, PaymentHeld, Shipped, Delivered, Released, Refunded, Disputed }

    /**
     * @dev Struct containing all information about a trade transaction
     * @param buyer Address of the buyer (payment sender)
     * @param seller Address of the seller (payment recipient)
     * @param verifier Address of trusted third party for document verification and disputes
     * @param value Amount of ETH held in escrow (in wei)
     * @param shipmentDetails Description of goods being traded
     * @param documentHash Cryptographic hash of trade documents (e.g., Bill of Lading)
     * @param documentVerified Boolean flag indicating if documents have been verified
     * @param state Current state of the trade transaction
     * @param createdAt Timestamp when the trade was created
     */
    struct Trade {
        address payable buyer;      // Buyer's wallet address
        address payable seller;     // Seller's wallet address  
        address verifier;           // Trusted third party for verification
        uint256 value;              // Escrow amount in wei
        string shipmentDetails;     // Description of shipment
        bytes32 documentHash;       // Hash of trade documents
        bool documentVerified;      // Document verification status
        State state;                // Current trade state
        uint256 createdAt;          // Creation timestamp
    }

    /// @dev Counter for generating unique trade IDs, starts at 1
    uint256 public nextTradeId = 1;
    
    /// @dev Mapping from trade ID to Trade struct containing all trade information
    mapping(uint256 => Trade) public trades;

    /// @dev Withdrawal pattern: mapping from address to pending withdrawal amount
    /// This prevents reentrancy attacks by separating balance tracking from ETH transfers
    mapping(address => uint256) public pendingWithdrawals;

    // ==================== EVENTS ====================
    
    /// @dev Emitted when a new trade is created
    event TradeCreated(uint256 indexed tradeId, address indexed buyer, address indexed seller, uint256 value);
    
    /// @dev Emitted when seller submits trade documents
    event DocumentSubmitted(uint256 indexed tradeId, bytes32 docHash);
    
    /// @dev Emitted when verifier verifies submitted documents
    event DocumentVerified(uint256 indexed tradeId, address verifier);
    
    /// @dev Emitted when seller marks goods as shipped
    event MarkedShipped(uint256 indexed tradeId);
    
    /// @dev Emitted when buyer confirms delivery
    event DeliveryConfirmed(uint256 indexed tradeId);
    
    /// @dev Emitted when payment is released to seller
    event PaymentReleased(uint256 indexed tradeId, address seller, uint256 amount);
    
    /// @dev Emitted when payment is refunded to buyer
    event Refunded(uint256 indexed tradeId, address buyer, uint256 amount);
    
    /// @dev Emitted when a dispute is raised
    event DisputeRaised(uint256 indexed tradeId);
    
    /// @dev Emitted when a dispute is resolved
    event DisputeResolved(uint256 indexed tradeId, address resolver, string action);

    // ==================== MODIFIERS ====================
    
    /**
     * @dev Restricts function access to only the buyer of a specific trade
     * @param tradeId The ID of the trade to check
     */
    modifier onlyBuyer(uint256 tradeId) {
        require(msg.sender == trades[tradeId].buyer, "Only buyer allowed");
        _;
    }

    /**
     * @dev Restricts function access to only the seller of a specific trade
     * @param tradeId The ID of the trade to check
     */
    modifier onlySeller(uint256 tradeId) {
        require(msg.sender == trades[tradeId].seller, "Only seller allowed");
        _;
    }

    /**
     * @dev Restricts function access to only the verifier of a specific trade
     * @param tradeId The ID of the trade to check
     */
    modifier onlyVerifier(uint256 tradeId) {
        require(msg.sender == trades[tradeId].verifier, "Only verifier allowed");
        _;
    }

    /**
     * @dev Ensures the trade is in the expected state before function execution
     * @param tradeId The ID of the trade to check
     * @param expected The expected state for the trade
     */
    modifier inState(uint256 tradeId, State expected) {
        require(trades[tradeId].state == expected, "Invalid state for this action");
        _;
    }

    /**
     * @dev Validates that a trade with the given ID exists
     * @param tradeId The ID of the trade to validate
     */
    modifier tradeExists(uint256 tradeId) {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
        _;
    }

    // ==================== CONSTRUCTOR ====================
    
    /**
     * @dev Contract constructor - initializes the contract with nextTradeId = 1
     * Trade ID 0 is reserved for validation purposes (non-existent trades)
     */
    constructor() {
        // nextTradeId is already initialized to 1 in declaration
        // This ensures trade ID 0 can be used to check for non-existent trades
    }

    // ==================== CORE FUNCTIONS ====================

    /**
     * @notice REQUIREMENT 1: Transaction Initiation
     * @dev Creates a new trade transaction with buyer depositing payment into escrow
     * @param seller The address of the seller who will receive payment
     * @param verifier The address of the trusted third party for document verification
     * @param shipmentDetails Description of the goods being traded
     * @return tradeId The unique identifier for the created trade
     */
    function createTrade(
        address payable seller,
        address verifier,
        string memory shipmentDetails
    ) external payable returns (uint256) {
        // Input validation
        require(msg.value > 0, "Must send payment");
        require(seller != address(0), "Invalid seller address");
        require(verifier != address(0), "Invalid verifier address");
        require(seller != msg.sender, "Buyer and seller cannot be the same");

        // Generate unique trade ID and increment counter
        uint256 tradeId = nextTradeId;
        nextTradeId = nextTradeId + 1;
        
        // Create new trade with buyer's payment held in escrow
        trades[tradeId].buyer = payable(msg.sender);
        trades[tradeId].seller = seller;
        trades[tradeId].verifier = verifier;
        trades[tradeId].value = msg.value;  // Payment deposited into contract
        trades[tradeId].shipmentDetails = shipmentDetails;
        trades[tradeId].documentHash = bytes32(0);  // No documents submitted yet
        trades[tradeId].documentVerified = false;
        trades[tradeId].state = State.PaymentHeld;  // Payment is now held in escrow
        trades[tradeId].createdAt = block.timestamp;

        // Emit event for transparency and off-chain monitoring
        emit TradeCreated(tradeId, msg.sender, seller, msg.value);
        return tradeId;
    }

    /**
     * @notice REQUIREMENT 2: Document Verification (Part 1) - Document Submission
     * @dev Allows seller to submit cryptographic hash of trade documents
     * @param tradeId The ID of the trade for document submission
     * @param docHash The cryptographic hash of trade documents (e.g., Bill of Lading)
     */
    function submitDocuments(uint256 tradeId, bytes32 docHash) external 
        tradeExists(tradeId)
        onlySeller(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(docHash != bytes32(0), "Document hash cannot be empty");
        
        // Store document hash for verification
        trades[tradeId].documentHash = docHash;
        emit DocumentSubmitted(tradeId, docHash);
    }

    /**
     * @notice REQUIREMENT 2: Document Verification (Part 2) - Document Authentication
     * @dev Allows verifier to authenticate submitted documents
     * @param tradeId The ID of the trade for document verification
     */
    function verifyDocuments(uint256 tradeId) external 
        tradeExists(tradeId)
        onlyVerifier(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(trades[tradeId].documentHash != bytes32(0), "No documents submitted");
        
        // Mark documents as verified by trusted third party
        trades[tradeId].documentVerified = true;
        emit DocumentVerified(tradeId, msg.sender);
    }

    /**
     * @notice REQUIREMENT 3: Shipment Tracking (Part 1) - Mark as Shipped
     * @dev Allows seller to mark goods as shipped after document verification
     * @param tradeId The ID of the trade to mark as shipped
     */
    function markShipped(uint256 tradeId) external 
        tradeExists(tradeId)
        onlySeller(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(trades[tradeId].documentVerified, "Documents must be verified first");
        
        // Update state to Shipped - goods are now in transit
        trades[tradeId].state = State.Shipped;
        emit MarkedShipped(tradeId);
    }

    /**
     * @notice REQUIREMENT 3: Shipment Tracking (Part 2) + REQUIREMENT 4: Automated Payment
     * @dev Buyer confirms delivery, automatically triggering payment release
     * @param tradeId The ID of the trade to confirm delivery for
     */
    function confirmDelivery(uint256 tradeId) external 
        tradeExists(tradeId)
        onlyBuyer(tradeId) 
        inState(tradeId, State.Shipped) 
    {
        // Update state to Delivered
        trades[tradeId].state = State.Delivered;
        emit DeliveryConfirmed(tradeId);
        
        // AUTOMATED PAYMENT: Automatically release payment to seller
        // This fulfills Requirement 4: Automated Payments
        trades[tradeId].state = State.Released;
        pendingWithdrawals[trades[tradeId].seller] = 
            pendingWithdrawals[trades[tradeId].seller] + trades[tradeId].value;
        emit PaymentReleased(tradeId, trades[tradeId].seller, trades[tradeId].value);
    }

    /**
     * @notice REQUIREMENT 5: Dispute Resolution (Part 1) - Raise Dispute
     * @dev Allows buyer or seller to raise a dispute
     * @param tradeId The ID of the trade to dispute
     */
    function raiseDispute(uint256 tradeId) external 
        tradeExists(tradeId)
    {
        require(
            msg.sender == trades[tradeId].buyer || msg.sender == trades[tradeId].seller,
            "Only buyer or seller can raise dispute"
        );
        require(
            trades[tradeId].state == State.PaymentHeld || 
            trades[tradeId].state == State.Shipped,
            "Cannot dispute in current state"
        );
        
        // Change state to Disputed - halts normal trade progression
        trades[tradeId].state = State.Disputed;
        emit DisputeRaised(tradeId);
    }

    /**
     * @notice REQUIREMENT 5: Dispute Resolution (Part 2) - Resolve Dispute
     * @dev Allows trusted verifier to resolve disputes and override transaction state
     * @param tradeId The ID of the trade dispute to resolve
     * @param refundToBuyer True to refund buyer, false to pay seller
     * @param reason Human-readable reason for the resolution decision
     */
    function resolveDispute(
        uint256 tradeId, 
        bool refundToBuyer, 
        string memory reason
    ) external 
        tradeExists(tradeId)
        onlyVerifier(tradeId) 
        inState(tradeId, State.Disputed) 
    {
        if (refundToBuyer) {
            // Refund to buyer - dispute resolved in buyer's favor
            trades[tradeId].state = State.Refunded;
            pendingWithdrawals[trades[tradeId].buyer] = 
                pendingWithdrawals[trades[tradeId].buyer] + trades[tradeId].value;
            emit Refunded(tradeId, trades[tradeId].buyer, trades[tradeId].value);
        } else {
            // Pay seller - dispute resolved in seller's favor
            trades[tradeId].state = State.Released;
            pendingWithdrawals[trades[tradeId].seller] = 
                pendingWithdrawals[trades[tradeId].seller] + trades[tradeId].value;
            emit PaymentReleased(tradeId, trades[tradeId].seller, trades[tradeId].value);
        }
        
        emit DisputeResolved(tradeId, msg.sender, reason);
    }

    /**
     * @notice Secure withdrawal function implementing withdrawal pattern
     * @dev Allows users to withdraw their pending funds (prevents reentrancy attacks)
     */
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        // Reset balance before transfer to prevent reentrancy
        pendingWithdrawals[msg.sender] = 0;
        
        // Use low-level call for secure ETH transfer
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Emergency refund mechanism for stalled trades
     * @dev Allows buyer to claim refund if trade is stuck in PaymentHeld for 30+ days
     * @param tradeId The ID of the trade to request emergency refund for
     */
    function emergencyRefund(uint256 tradeId) external 
        tradeExists(tradeId)
        onlyBuyer(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(
            block.timestamp > trades[tradeId].createdAt + 30 days,
            "Emergency refund only after 30 days"
        );
        
        // Process emergency refund
        trades[tradeId].state = State.Refunded;
        pendingWithdrawals[trades[tradeId].buyer] = 
            pendingWithdrawals[trades[tradeId].buyer] + trades[tradeId].value;
        
        emit Refunded(tradeId, trades[tradeId].buyer, trades[tradeId].value);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Retrieves complete information about a specific trade
     * @param tradeId The ID of the trade to retrieve
     * @return buyer Address of the buyer
     * @return seller Address of the seller
     * @return verifier Address of the verifier
     * @return value Amount held in escrow (wei)
     * @return shipmentDetails Description of the shipment
     * @return documentHash Hash of trade documents
     * @return documentVerified Whether documents are verified
     * @return state Current state of the trade
     * @return createdAt Timestamp when trade was created
     */
    function getTrade(uint256 tradeId) external view 
        tradeExists(tradeId)
        returns (
            address buyer,
            address seller,
            address verifier,
            uint256 value,
            string memory shipmentDetails,
            bytes32 documentHash,
            bool documentVerified,
            State state,
            uint256 createdAt
        ) 
    {
        Trade memory trade = trades[tradeId];
        return (
            trade.buyer,
            trade.seller,
            trade.verifier,
            trade.value,
            trade.shipmentDetails,
            trade.documentHash,
            trade.documentVerified,
            trade.state,
            trade.createdAt
        );
    }

    /**
     * @notice Gets the pending withdrawal balance for a specific address
     * @param account The address to check pending withdrawals for
     * @return The amount available for withdrawal (in wei)
     */
    function getPendingWithdrawal(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    /**
     * @notice Gets the total ETH balance held by the contract
     * @return The contract's ETH balance (in wei)
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Utility function to generate cryptographic hash of documents
     * @param document The document content to hash
     * @return The keccak256 hash of the document
     */
    function generateDocumentHash(string memory document) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(document));
    }
}

/**
 * @dev ASSIGNMENT REQUIREMENTS IMPLEMENTATION SUMMARY:
 * 
 * ✅ REQUIREMENT 1: Transaction Initiation
 *    - Implemented in createTrade() function
 *    - Buyer deposits payment into smart contract escrow
 *    - Stores all key trade details (value, shipment details, parties)
 * 
 * ✅ REQUIREMENT 2: Document Verification  
 *    - Implemented in submitDocuments() and verifyDocuments() functions
 *    - Uses cryptographic hashing for document integrity
 *    - Third-party verifier authenticates documents
 * 
 * ✅ REQUIREMENT 3: Shipment Tracking
 *    - Implemented via State enum and state transitions
 *    - States: PaymentHeld → Shipped → Delivered → Released
 *    - markShipped() and confirmDelivery() update states
 * 
 * ✅ REQUIREMENT 4: Automated Payments
 *    - Implemented in confirmDelivery() function
 *    - Automatically releases payment when delivery confirmed
 *    - Uses withdrawal pattern for secure fund management
 * 
 * ✅ REQUIREMENT 5: Dispute Resolution
 *    - Implemented in raiseDispute() and resolveDispute() functions
 *    - Trusted third party can override transaction state
 *    - Supports both buyer refunds and seller payments
 * 
 * BONUS FEATURES:
 * - Emergency refund mechanism (30-day timeout)
 * - Comprehensive event logging for transparency
 * - Reentrancy protection via withdrawal pattern
 * - Access control modifiers for security
 * - Input validation throughout
 */
