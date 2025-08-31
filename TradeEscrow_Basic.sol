// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TradeEscrow Basic - Guaranteed to work in Remix
 * @notice Ultra-simple version using older Solidity syntax
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

    uint256 public nextTradeId = 1;
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
        // Constructor is empty - nextTradeId already initialized
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
        
        trades[tradeId].buyer = payable(msg.sender);
        trades[tradeId].seller = seller;
        trades[tradeId].verifier = verifier;
        trades[tradeId].value = msg.value;
        trades[tradeId].shipmentDetails = shipmentDetails;
        trades[tradeId].documentHash = bytes32(0);
        trades[tradeId].documentVerified = false;
        trades[tradeId].state = State.PaymentHeld;
        trades[tradeId].createdAt = block.timestamp;

        emit TradeCreated(tradeId, msg.sender, seller, msg.value);
        return tradeId;
    }

    function submitDocuments(uint256 tradeId, bytes32 docHash) public {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
        require(msg.sender == trades[tradeId].seller, "Only seller allowed");
        require(trades[tradeId].state == State.PaymentHeld, "Invalid state");
        require(docHash != bytes32(0), "Document hash cannot be empty");
        
        trades[tradeId].documentHash = docHash;
        emit DocumentSubmitted(tradeId, docHash);
    }

    function verifyDocuments(uint256 tradeId) public {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
        require(msg.sender == trades[tradeId].verifier, "Only verifier allowed");
        require(trades[tradeId].state == State.PaymentHeld, "Invalid state");
        require(trades[tradeId].documentHash != bytes32(0), "No documents submitted");
        
        trades[tradeId].documentVerified = true;
        emit DocumentVerified(tradeId, msg.sender);
    }

    function markShipped(uint256 tradeId) public {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
        require(msg.sender == trades[tradeId].seller, "Only seller allowed");
        require(trades[tradeId].state == State.PaymentHeld, "Invalid state");
        require(trades[tradeId].documentVerified, "Documents must be verified first");
        
        trades[tradeId].state = State.Shipped;
        emit MarkedShipped(tradeId);
    }

    function confirmDelivery(uint256 tradeId) public {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
        require(msg.sender == trades[tradeId].buyer, "Only buyer allowed");
        require(trades[tradeId].state == State.Shipped, "Invalid state");
        
        trades[tradeId].state = State.Delivered;
        emit DeliveryConfirmed(tradeId);
        
        // Release payment
        trades[tradeId].state = State.Released;
        pendingWithdrawals[trades[tradeId].seller] = pendingWithdrawals[trades[tradeId].seller] + trades[tradeId].value;
        emit PaymentReleased(tradeId, trades[tradeId].seller, trades[tradeId].value);
    }

    function raiseDispute(uint256 tradeId) public {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
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
    ) public {
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
        require(msg.sender == trades[tradeId].verifier, "Only verifier allowed");
        require(trades[tradeId].state == State.Disputed, "Invalid state");
        
        if (refundToBuyer) {
            trades[tradeId].state = State.Refunded;
            pendingWithdrawals[trades[tradeId].buyer] = pendingWithdrawals[trades[tradeId].buyer] + trades[tradeId].value;
            emit Refunded(tradeId, trades[tradeId].buyer, trades[tradeId].value);
        } else {
            trades[tradeId].state = State.Released;
            pendingWithdrawals[trades[tradeId].seller] = pendingWithdrawals[trades[tradeId].seller] + trades[tradeId].value;
            emit PaymentReleased(tradeId, trades[tradeId].seller, trades[tradeId].value);
        }
        
        emit DisputeResolved(tradeId, msg.sender, reason);
    }

    function withdraw() public {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    // View functions
    function getTrade(uint256 tradeId) public view returns (
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
        require(tradeId > 0 && tradeId < nextTradeId, "Trade does not exist");
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

    function getPendingWithdrawal(address account) public view returns (uint256) {
        return pendingWithdrawals[account];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function generateDocumentHash(string memory document) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(document));
    }
}
