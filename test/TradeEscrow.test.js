const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TradeEscrow", function () {
  let TradeEscrow;
  let tradeEscrow;
  let buyer, seller, verifier, other;
  let tradeValue;

  beforeEach(async function () {
    // Get signers
    [buyer, seller, verifier, other] = await ethers.getSigners();

    // Deploy contract
    TradeEscrow = await ethers.getContractFactory("TradeEscrow");
    tradeEscrow = await TradeEscrow.deploy();
    await tradeEscrow.waitForDeployment();

    // Set trade value
    tradeValue = ethers.parseEther("1.0");
  });

  describe("Contract Deployment", function () {
    it("Should set the correct initial state", async function () {
      expect(await tradeEscrow.nextTradeId()).to.equal(1);
    });
  });

  describe("Trade Creation", function () {
    it("Should create a new trade successfully", async function () {
      const shipmentDetails = "Electronics shipment from A to B";
      
      await expect(
        tradeEscrow.connect(buyer).createTrade(
          seller.address,
          verifier.address,
          shipmentDetails,
          { value: tradeValue }
        )
      )
        .to.emit(tradeEscrow, "TradeCreated")
        .withArgs(1, buyer.address, seller.address, tradeValue);

      const trade = await tradeEscrow.getTrade(1);
      expect(trade.buyer).to.equal(buyer.address);
      expect(trade.seller).to.equal(seller.address);
      expect(trade.verifier).to.equal(verifier.address);
      expect(trade.value).to.equal(tradeValue);
      expect(trade.shipmentDetails).to.equal(shipmentDetails);
      expect(trade.state).to.equal(1); // PaymentHeld
    });

    it("Should fail when no payment is sent", async function () {
      await expect(
        tradeEscrow.connect(buyer).createTrade(
          seller.address,
          verifier.address,
          "Test shipment"
        )
      ).to.be.revertedWith("Must send payment");
    });

    it("Should fail when seller address is invalid", async function () {
      await expect(
        tradeEscrow.connect(buyer).createTrade(
          ethers.ZeroAddress,
          verifier.address,
          "Test shipment",
          { value: tradeValue }
        )
      ).to.be.revertedWith("Invalid seller address");
    });

    it("Should fail when buyer and seller are the same", async function () {
      await expect(
        tradeEscrow.connect(buyer).createTrade(
          buyer.address,
          verifier.address,
          "Test shipment",
          { value: tradeValue }
        )
      ).to.be.revertedWith("Buyer and seller cannot be the same");
    });
  });

  describe("Document Submission and Verification", function () {
    let tradeId;
    const docHash = ethers.keccak256(ethers.toUtf8Bytes("Bill of Lading content"));

    beforeEach(async function () {
      // Create a trade first
      await tradeEscrow.connect(buyer).createTrade(
        seller.address,
        verifier.address,
        "Test shipment",
        { value: tradeValue }
      );
      tradeId = 1;
    });

    it("Should allow seller to submit documents", async function () {
      await expect(
        tradeEscrow.connect(seller).submitDocuments(tradeId, docHash)
      )
        .to.emit(tradeEscrow, "DocumentSubmitted")
        .withArgs(tradeId, docHash);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.documentHash).to.equal(docHash);
    });

    it("Should allow verifier to verify documents", async function () {
      // Submit documents first
      await tradeEscrow.connect(seller).submitDocuments(tradeId, docHash);

      await expect(
        tradeEscrow.connect(verifier).verifyDocuments(tradeId)
      )
        .to.emit(tradeEscrow, "DocumentVerified")
        .withArgs(tradeId, verifier.address);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.documentVerified).to.be.true;
    });

    it("Should fail when non-seller tries to submit documents", async function () {
      await expect(
        tradeEscrow.connect(buyer).submitDocuments(tradeId, docHash)
      ).to.be.revertedWith("Only seller allowed");
    });

    it("Should fail when non-verifier tries to verify documents", async function () {
      await tradeEscrow.connect(seller).submitDocuments(tradeId, docHash);
      
      await expect(
        tradeEscrow.connect(buyer).verifyDocuments(tradeId)
      ).to.be.revertedWith("Only verifier allowed");
    });
  });

  describe("Shipping and Delivery", function () {
    let tradeId;
    const docHash = ethers.keccak256(ethers.toUtf8Bytes("Bill of Lading content"));

    beforeEach(async function () {
      // Create trade, submit and verify documents
      await tradeEscrow.connect(buyer).createTrade(
        seller.address,
        verifier.address,
        "Test shipment",
        { value: tradeValue }
      );
      tradeId = 1;
      
      await tradeEscrow.connect(seller).submitDocuments(tradeId, docHash);
      await tradeEscrow.connect(verifier).verifyDocuments(tradeId);
    });

    it("Should allow seller to mark as shipped", async function () {
      await expect(
        tradeEscrow.connect(seller).markShipped(tradeId)
      )
        .to.emit(tradeEscrow, "MarkedShipped")
        .withArgs(tradeId);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.state).to.equal(2); // Shipped
    });

    it("Should allow buyer to confirm delivery and release payment", async function () {
      // Mark as shipped first
      await tradeEscrow.connect(seller).markShipped(tradeId);

      await expect(
        tradeEscrow.connect(buyer).confirmDelivery(tradeId)
      )
        .to.emit(tradeEscrow, "DeliveryConfirmed")
        .withArgs(tradeId)
        .and.to.emit(tradeEscrow, "PaymentReleased")
        .withArgs(tradeId, seller.address, tradeValue);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.state).to.equal(4); // Released

      // Check pending withdrawal
      expect(await tradeEscrow.getPendingWithdrawal(seller.address)).to.equal(tradeValue);
    });
  });

  describe("Withdrawals", function () {
    let tradeId;
    const docHash = ethers.keccak256(ethers.toUtf8Bytes("Bill of Lading content"));

    beforeEach(async function () {
      // Complete a full trade flow
      await tradeEscrow.connect(buyer).createTrade(
        seller.address,
        verifier.address,
        "Test shipment",
        { value: tradeValue }
      );
      tradeId = 1;
      
      await tradeEscrow.connect(seller).submitDocuments(tradeId, docHash);
      await tradeEscrow.connect(verifier).verifyDocuments(tradeId);
      await tradeEscrow.connect(seller).markShipped(tradeId);
      await tradeEscrow.connect(buyer).confirmDelivery(tradeId);
    });

    it("Should allow seller to withdraw funds", async function () {
      const initialBalance = await ethers.provider.getBalance(seller.address);
      
      const tx = await tradeEscrow.connect(seller).withdraw();
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;
      
      const finalBalance = await ethers.provider.getBalance(seller.address);
      expect(finalBalance).to.equal(initialBalance + tradeValue - gasUsed);
      
      // Pending withdrawal should be zero
      expect(await tradeEscrow.getPendingWithdrawal(seller.address)).to.equal(0);
    });

    it("Should fail when trying to withdraw with no pending funds", async function () {
      await expect(
        tradeEscrow.connect(buyer).withdraw()
      ).to.be.revertedWith("No funds to withdraw");
    });
  });

  describe("Disputes", function () {
    let tradeId;
    const docHash = ethers.keccak256(ethers.toUtf8Bytes("Bill of Lading content"));

    beforeEach(async function () {
      await tradeEscrow.connect(buyer).createTrade(
        seller.address,
        verifier.address,
        "Test shipment",
        { value: tradeValue }
      );
      tradeId = 1;
    });

    it("Should allow buyer to raise dispute", async function () {
      await expect(
        tradeEscrow.connect(buyer).raiseDispute(tradeId)
      )
        .to.emit(tradeEscrow, "DisputeRaised")
        .withArgs(tradeId);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.state).to.equal(6); // Disputed
    });

    it("Should allow verifier to resolve dispute in favor of buyer", async function () {
      await tradeEscrow.connect(buyer).raiseDispute(tradeId);

      const reason = "Goods not as described";
      await expect(
        tradeEscrow.connect(verifier).resolveDispute(tradeId, true, reason)
      )
        .to.emit(tradeEscrow, "DisputeResolved")
        .withArgs(tradeId, verifier.address, reason)
        .and.to.emit(tradeEscrow, "Refunded")
        .withArgs(tradeId, buyer.address, tradeValue);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.state).to.equal(5); // Refunded
      expect(await tradeEscrow.getPendingWithdrawal(buyer.address)).to.equal(tradeValue);
    });

    it("Should allow verifier to resolve dispute in favor of seller", async function () {
      await tradeEscrow.connect(buyer).raiseDispute(tradeId);

      const reason = "Goods delivered as agreed";
      await expect(
        tradeEscrow.connect(verifier).resolveDispute(tradeId, false, reason)
      )
        .to.emit(tradeEscrow, "DisputeResolved")
        .withArgs(tradeId, verifier.address, reason)
        .and.to.emit(tradeEscrow, "PaymentReleased")
        .withArgs(tradeId, seller.address, tradeValue);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.state).to.equal(4); // Released
      expect(await tradeEscrow.getPendingWithdrawal(seller.address)).to.equal(tradeValue);
    });
  });

  describe("Emergency Refund", function () {
    let tradeId;

    beforeEach(async function () {
      await tradeEscrow.connect(buyer).createTrade(
        seller.address,
        verifier.address,
        "Test shipment",
        { value: tradeValue }
      );
      tradeId = 1;
    });

    it("Should fail emergency refund before 30 days", async function () {
      await expect(
        tradeEscrow.connect(buyer).emergencyRefund(tradeId)
      ).to.be.revertedWith("Emergency refund only after 30 days");
    });

    it("Should allow emergency refund after 30 days", async function () {
      // Fast forward time by 31 days
      await ethers.provider.send("evm_increaseTime", [31 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      await expect(
        tradeEscrow.connect(buyer).emergencyRefund(tradeId)
      )
        .to.emit(tradeEscrow, "Refunded")
        .withArgs(tradeId, buyer.address, tradeValue);

      const trade = await tradeEscrow.getTrade(tradeId);
      expect(trade.state).to.equal(5); // Refunded
      expect(await tradeEscrow.getPendingWithdrawal(buyer.address)).to.equal(tradeValue);
    });
  });
});
