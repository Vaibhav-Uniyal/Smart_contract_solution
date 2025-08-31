// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TradeEscrow - Simple Version for Remix IDE
 * @notice Simplified escrow contract that should work reliably in Remix IDE
 */
contract TradeEscrow {
    
    enum State { Created, PaymentHeld, Shipped, Delivered, Released, Refunded, Disputed }

    struct Trade {
        address payable buyer;
        address payable seller;
        address verifier;
        uint256 value;
        string shipmentDetails;
        bytes32 documentHash;
        bool documentVerified;
        State state;
        uint256 createdAt;
    }

    uint256 public nextTradeId;
    mapping(uint256 => Trade) public trades;
    mapping(address => uint256) public pendingWithdrawals;

    event TradeCreated(uint256 indexed tradeId, address indexed buyer, address indexed seller, uint256 value);
    event DocumentSubmitted(uint256 indexed tradeId, bytes32 docHash);
    event DocumentVerified(uint256 indexed tradeId, address verifier);
    event MarkedShipped(uint256 indexed tradeId);
    event DeliveryConfirmed(uint256 indexed tradeId);
    event PaymentReleased(uint256 indexed tradeId, address seller, uint256 amount);
    event Refunded(uint256 indexed tradeId, address buyer, uint256 amount);
    event DisputeRaised(uint256 indexed tradeId);
    event DisputeResolved(uint256 indexed tradeId, address resolver, string action);

    constructor() {
        nextTradeId = 1;
    }

    function createTrade(
        address payable seller,
        address verifier,
        string memory shipmentDetails
    ) external payable returns (uint256) {
        require(msg.value > 0, "Must send payment");
        require(seller != address(0), "Invalid seller address");
        require(verifier != address(0), "Invalid verifier address");
        require(seller != msg.sender, "Buyer and seller cannot be the same");

        uint256 tradeId = nextTradeId;
        nextTradeId = nextTradeId + 1;
        
        Trade storage newTrade = trades[tradeId];
        newTrade.buyer = payable(msg.sender);
        newTrade.seller = seller;
        newTrade.verifier = verifier;
        newTrade.value = msg.value;
        newTrade.shipmentDetails = shipmentDetails;
        newTrade.documentHash = bytes32(0);
        newTrade.documentVerified = false;
        newTrade.state = State.PaymentHeld;
        newTrade.createdAt = block.timestamp;

        emit TradeCreated(tradeId, msg.sender, seller, msg.value);
        return tradeId;
    }

    function submitDocuments(uint256 tradeId, bytes32 docHash) external {
        require(tradeExists(tradeId), "Trade does not exist");
        require(msg.sender == trades[tradeId].seller, "Only seller allowed");
        require(trades[tradeId].state == State.PaymentHeld, "Invalid state for this action");
        require(docHash != bytes32(0), "Document hash cannot be empty");
        
        trades[tradeId].documentHash = docHash;
        emit DocumentSubmitted(tradeId, docHash);
    }

    function verifyDocuments(uint256 tradeId) external {
        require(tradeExists(tradeId), "Trade does not exist");
        require(msg.sender == trades[tradeId].verifier, "Only verifier allowed");
        require(trades[tradeId].state == State.PaymentHeld, "Invalid state for this action");
        require(trades[tradeId].documentHash != bytes32(0), "No documents submitted");
        
        trades[tradeId].documentVerified = true;
        emit DocumentVerified(tradeId, msg.sender);
    }

    function markShipped(uint256 tradeId) external {
        require(tradeExists(tradeId), "Trade does not exist");
        require(msg.sender == trades[tradeId].seller, "Only seller allowed");
        require(trades[tradeId].state == State.PaymentHeld, "Invalid state for this action");
        require(trades[tradeId].documentVerified, "Documents must be verified first");
        
        trades[tradeId].state = State.Shipped;
        emit MarkedShipped(tradeId);
    }

    function confirmDelivery(uint256 tradeId) external {
        require(tradeExists(tradeId), "Trade does not exist");
        require(msg.sender == trades[tradeId].buyer, "Only buyer allowed");
        require(trades[tradeId].state == State.Shipped, "Invalid state for this action");
        
        trades[tradeId].state = State.Delivered;
        emit DeliveryConfirmed(tradeId);
        
        // Automatically release payment
        releasePayment(tradeId);
    }

    function releasePayment(uint256 tradeId) internal {
        Trade storage trade = trades[tradeId];
        require(trade.state == State.Delivered, "Trade must be delivered");
        
        trade.state = State.Released;
        pendingWithdrawals[trade.seller] = pendingWithdrawals[trade.seller] + trade.value;
        
        emit PaymentReleased(tradeId, trade.seller, trade.value);
    }

    function raiseDispute(uint256 tradeId) external {
        require(tradeExists(tradeId), "Trade does not exist");
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

    function resolveDispute(
        uint256 tradeId, 
        bool refundToBuyer, 
        string memory reason
    ) external {
        require(tradeExists(tradeId), "Trade does not exist");
        require(msg.sender == trades[tradeId].verifier, "Only verifier allowed");
        require(trades[tradeId].state == State.Disputed, "Invalid state for this action");
        
        Trade storage trade = trades[tradeId];
        
        if (refundToBuyer) {
            trade.state = State.Refunded;
            pendingWithdrawals[trade.buyer] = pendingWithdrawals[trade.buyer] + trade.value;
            emit Refunded(tradeId, trade.buyer, trade.value);
        } else {
            trade.state = State.Released;
            pendingWithdrawals[trade.seller] = pendingWithdrawals[trade.seller] + trade.value;
            emit PaymentReleased(tradeId, trade.seller, trade.value);
        }
        
        emit DisputeResolved(tradeId, msg.sender, reason);
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    function emergencyRefund(uint256 tradeId) external {
        require(tradeExists(tradeId), "Trade does not exist");
        require(msg.sender == trades[tradeId].buyer, "Only buyer allowed");
        require(trades[tradeId].state == State.PaymentHeld, "Invalid state for this action");
        require(
            block.timestamp > trades[tradeId].createdAt + 30 days,
            "Emergency refund only after 30 days"
        );
        
        Trade storage trade = trades[tradeId];
        trade.state = State.Refunded;
        pendingWithdrawals[trade.buyer] = pendingWithdrawals[trade.buyer] + trade.value;
        
        emit Refunded(tradeId, trade.buyer, trade.value);
    }

    // View functions
    function getTrade(uint256 tradeId) external view returns (
        address buyer,
        address seller,
        address verifier,
        uint256 value,
        string memory shipmentDetails,
        bytes32 documentHash,
        bool documentVerified,
        State state,
        uint256 createdAt
    ) {
        require(tradeExists(tradeId), "Trade does not exist");
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

    function getPendingWithdrawal(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getCurrentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function generateDocumentHash(string memory document) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(document));
    }

    // Helper function
    function tradeExists(uint256 tradeId) internal view returns (bool) {
        return tradeId > 0 && tradeId < nextTradeId;
    }
}
