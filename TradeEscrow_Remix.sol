// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TradeEscrow
 * @notice Escrow contract for a simple trade finance flow. Buyer deposits payment; funds released to seller
 * after document verification and delivery confirmation. A trusted arbiter can resolve disputes.
 * @dev This version is optimized for Remix IDE
 */
contract TradeEscrow {
    // Roles: buyer, seller, verifier (arbiter)

    enum State { Created, PaymentHeld, Shipped, Delivered, Released, Refunded, Disputed }

    struct Trade {
        address payable buyer;
        address payable seller;
        address verifier; // trusted third party (could verify docs and resolve disputes)
        uint256 value; // escrow value in wei
        string shipmentDetails; // brief description (off-chain canonical reference)
        bytes32 documentHash; // hash of trade documents (e.g., Bill of Lading)
        bool documentVerified; // set true by verifier or authorized party
        State state;
        uint256 createdAt;
    }

    uint256 public nextTradeId;
    mapping(uint256 => Trade) public trades;

    // Withdrawal pattern storage: balances owed to accounts
    mapping(address => uint256) public pendingWithdrawals;

    // Events for off-chain listening
    event TradeCreated(uint256 indexed tradeId, address indexed buyer, address indexed seller, uint256 value);
    event DocumentSubmitted(uint256 indexed tradeId, bytes32 docHash);
    event DocumentVerified(uint256 indexed tradeId, address verifier);
    event MarkedShipped(uint256 indexed tradeId);
    event DeliveryConfirmed(uint256 indexed tradeId);
    event PaymentReleased(uint256 indexed tradeId, address seller, uint256 amount);
    event Refunded(uint256 indexed tradeId, address buyer, uint256 amount);
    event DisputeRaised(uint256 indexed tradeId);
    event DisputeResolved(uint256 indexed tradeId, address resolver, string action);

    modifier onlyBuyer(uint256 tradeId) {
        require(msg.sender == trades[tradeId].buyer, "Only buyer allowed");
        _;
    }

    modifier onlySeller(uint256 tradeId) {
        require(msg.sender == trades[tradeId].seller, "Only seller allowed");
        _;
    }

    modifier onlyVerifier(uint256 tradeId) {
        require(msg.sender == trades[tradeId].verifier, "Only verifier allowed");
        _;
    }

    modifier inState(uint256 tradeId, State expected) {
        require(trades[tradeId].state == expected, "Invalid state for this action");
        _;
    }

    modifier tradeExists(uint256 tradeId) {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
        _;
    }

    constructor() {
        nextTradeId = 1;
    }

    /**
     * @notice Create a new trade escrow
     * @param seller The seller's address
     * @param verifier The verifier's address (trusted third party)
     * @param shipmentDetails Description of the shipment
     */
    function createTrade(
        address payable seller,
        address verifier,
        string memory shipmentDetails
    ) external payable returns (uint256) {
        require(msg.value > 0, "Must send payment");
        require(seller != address(0), "Invalid seller address");
        require(verifier != address(0), "Invalid verifier address");
        require(seller != msg.sender, "Buyer and seller cannot be the same");

        uint256 tradeId = nextTradeId++;
        
        trades[tradeId] = Trade({
            buyer: payable(msg.sender),
            seller: seller,
            verifier: verifier,
            value: msg.value,
            shipmentDetails: shipmentDetails,
            documentHash: bytes32(0),
            documentVerified: false,
            state: State.PaymentHeld,
            createdAt: block.timestamp
        });

        emit TradeCreated(tradeId, msg.sender, seller, msg.value);
        return tradeId;
    }

    /**
     * @notice Submit trade documents (hash)
     * @param tradeId The trade ID
     * @param docHash Hash of the trade documents
     */
    function submitDocuments(uint256 tradeId, bytes32 docHash) 
        external 
        tradeExists(tradeId)
        onlySeller(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(docHash != bytes32(0), "Document hash cannot be empty");
        
        trades[tradeId].documentHash = docHash;
        emit DocumentSubmitted(tradeId, docHash);
    }

    /**
     * @notice Verify submitted documents
     * @param tradeId The trade ID
     */
    function verifyDocuments(uint256 tradeId) 
        external 
        tradeExists(tradeId)
        onlyVerifier(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(trades[tradeId].documentHash != bytes32(0), "No documents submitted");
        
        trades[tradeId].documentVerified = true;
        emit DocumentVerified(tradeId, msg.sender);
    }

    /**
     * @notice Mark shipment as shipped
     * @param tradeId The trade ID
     */
    function markShipped(uint256 tradeId) 
        external 
        tradeExists(tradeId)
        onlySeller(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(trades[tradeId].documentVerified, "Documents must be verified first");
        
        trades[tradeId].state = State.Shipped;
        emit MarkedShipped(tradeId);
    }

    /**
     * @notice Confirm delivery of goods
     * @param tradeId The trade ID
     */
    function confirmDelivery(uint256 tradeId) 
        external 
        tradeExists(tradeId)
        onlyBuyer(tradeId) 
        inState(tradeId, State.Shipped) 
    {
        trades[tradeId].state = State.Delivered;
        emit DeliveryConfirmed(tradeId);
        
        // Automatically release payment
        _releasePayment(tradeId);
    }

    /**
     * @notice Release payment to seller (internal function)
     * @param tradeId The trade ID
     */
    function _releasePayment(uint256 tradeId) internal {
        Trade storage trade = trades[tradeId];
        require(trade.state == State.Delivered, "Trade must be delivered");
        
        trade.state = State.Released;
        pendingWithdrawals[trade.seller] += trade.value;
        
        emit PaymentReleased(tradeId, trade.seller, trade.value);
    }

    /**
     * @notice Raise a dispute
     * @param tradeId The trade ID
     */
    function raiseDispute(uint256 tradeId) 
        external 
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
        
        trades[tradeId].state = State.Disputed;
        emit DisputeRaised(tradeId);
    }

    /**
     * @notice Resolve dispute (verifier only)
     * @param tradeId The trade ID
     * @param refundToBuyer True to refund buyer, false to pay seller
     * @param reason Reason for the resolution
     */
    function resolveDispute(
        uint256 tradeId, 
        bool refundToBuyer, 
        string memory reason
    ) 
        external 
        tradeExists(tradeId)
        onlyVerifier(tradeId) 
        inState(tradeId, State.Disputed) 
    {
        Trade storage trade = trades[tradeId];
        
        if (refundToBuyer) {
            trade.state = State.Refunded;
            pendingWithdrawals[trade.buyer] += trade.value;
            emit Refunded(tradeId, trade.buyer, trade.value);
        } else {
            trade.state = State.Released;
            pendingWithdrawals[trade.seller] += trade.value;
            emit PaymentReleased(tradeId, trade.seller, trade.value);
        }
        
        emit DisputeResolved(tradeId, msg.sender, reason);
    }

    /**
     * @notice Withdraw pending funds
     */
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @notice Emergency refund (only if payment held for too long without progress)
     * @param tradeId The trade ID
     */
    function emergencyRefund(uint256 tradeId) 
        external 
        tradeExists(tradeId)
        onlyBuyer(tradeId) 
        inState(tradeId, State.PaymentHeld) 
    {
        require(
            block.timestamp > trades[tradeId].createdAt + 30 days,
            "Emergency refund only after 30 days"
        );
        
        Trade storage trade = trades[tradeId];
        trade.state = State.Refunded;
        pendingWithdrawals[trade.buyer] += trade.value;
        
        emit Refunded(tradeId, trade.buyer, trade.value);
    }

    /**
     * @notice Get trade details
     * @param tradeId The trade ID
     */
    function getTrade(uint256 tradeId) 
        external 
        view 
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
        Trade storage trade = trades[tradeId];
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
     * @notice Get pending withdrawal amount for an address
     * @param account The account address
     */
    function getPendingWithdrawal(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    /**
     * @notice Get contract balance (for debugging)
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Get current block timestamp (for testing time-based functions)
     */
    function getCurrentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    // Helper function to generate document hash (for testing in Remix)
    function generateDocumentHash(string memory document) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(document));
    }
}
