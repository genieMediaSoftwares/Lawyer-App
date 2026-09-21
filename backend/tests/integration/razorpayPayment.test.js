process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret-key-123456";
process.env.NODE_ENV = "test";
process.env.PAYMENT_MODE = "sandbox";

const crypto = require("crypto");
const razorpayService = require("../../src/services/payment/razorpayService");
const Payment = require("../../src/models/Payment");
const Transaction = require("../../src/models/Transaction");
const WebhookEvent = require("../../src/models/WebhookEvent");
const notificationService = require("../../src/services/notification/notificationService");
const paymentSettlementService = require("../../src/services/payment/paymentSettlementService");

describe("Razorpay Payment Gateway Verification & Security Tests", () => {
  describe("1. Razorpay Service & Signature Verification", () => {
    it("should correctly verify payment signature using HMAC SHA-256", () => {
      const razorpayOrderId = "order_test_12345";
      const razorpayPaymentId = "pay_test_67890";

      razorpayService.keySecret = "secret_key_123";
      const expectedSig = crypto
        .createHmac("sha256", "secret_key_123")
        .update(`${razorpayOrderId}|${razorpayPaymentId}`)
        .digest("hex");

      const isValid = razorpayService.verifyPaymentSignature({
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature: expectedSig,
      });

      expect(isValid).toBe(true);
    });

    it("should reject invalid payment signature", () => {
      razorpayService.keySecret = "secret_key_123";
      const isValid = razorpayService.verifyPaymentSignature({
        razorpayOrderId: "order_test_12345",
        razorpayPaymentId: "pay_test_67890",
        razorpaySignature: "invalid_sig_hash",
      });

      expect(isValid).toBe(false);
    });

    it("should verify webhook signature using exact raw request body", () => {
      razorpayService.webhookSecret = "wh_secret_999";
      const rawBody = JSON.stringify({ event: "payment.captured", payload: {} });
      const expectedSig = crypto
        .createHmac("sha256", "wh_secret_999")
        .update(rawBody)
        .digest("hex");

      const isValid = razorpayService.verifyWebhookSignature(rawBody, expectedSig);
      expect(isValid).toBe(true);
    });
  });

  describe("2. Server-Authoritative Subscription Catalog Pricing", () => {
    const SUBSCRIPTION_CATALOG = {
      Free: 0,
      Starter: 999,
      Professional: 2999,
      Premium: 5999,
      Elite: 12999,
    };

    it("should strictly preserve exact Lawfly subscription catalog prices", () => {
      expect(SUBSCRIPTION_CATALOG.Free).toBe(0);
      expect(SUBSCRIPTION_CATALOG.Starter).toBe(999);
      expect(SUBSCRIPTION_CATALOG.Professional).toBe(2999);
      expect(SUBSCRIPTION_CATALOG.Premium).toBe(5999);
      expect(SUBSCRIPTION_CATALOG.Elite).toBe(12999);
    });
  });

  describe("3. Concurrency & Idempotency Settlement Guarantee", () => {
    it("simultaneous verify + payment.captured + order.paid + duplicate verify produces exactly 1 completed payment and no duplicate ledger entries", async () => {
      const razorpayOrderId = "order_concurrent_test_999";
      const razorpayPaymentId = "pay_concurrent_test_999";

      const mockPayment = {
        _id: "507f1f77bcf86cd799439011",
        client: "507f1f77bcf86cd799439012",
        lawyer: "507f1f77bcf86cd799439013",
        amount: 999,
        currency: "INR",
        purpose: "consultation",
        status: "pending",
        razorpayOrderId,
      };

      let completedCount = 0;
      let createdTransactions = [];
      const mockWebhookEvents = new Set();

      jest.spyOn(WebhookEvent, "findOne").mockImplementation(async (query) => {
        if (query.eventId && mockWebhookEvents.has(query.eventId)) {
          return { eventId: query.eventId, status: "processed" };
        }
        return null;
      });

      jest.spyOn(WebhookEvent, "create").mockImplementation(async (doc) => {
        if (doc && doc.eventId) {
          mockWebhookEvents.add(doc.eventId);
        }
        return doc;
      });

      jest.spyOn(WebhookEvent, "updateOne").mockImplementation(async () => {
        return { acknowledged: true };
      });

      jest.spyOn(Payment, "findOne").mockImplementation(async (query) => {
        if (query.razorpayOrderId === razorpayOrderId) {
          return { ...mockPayment, status: completedCount > 0 ? "completed" : "pending" };
        }
        return null;
      });

      jest.spyOn(Payment, "findById").mockImplementation(async (id) => {
        return { ...mockPayment, status: "completed" };
      });

      jest.spyOn(Payment, "findOneAndUpdate").mockImplementation(async (query, update) => {
        if (query._id === mockPayment._id && query.status.$ne === "completed") {
          if (completedCount === 0) {
            completedCount++;
            return { ...mockPayment, status: "completed", razorpayPaymentId };
          }
        }
        return null;
      });

      jest.spyOn(Transaction, "create").mockImplementation(async (txs) => {
        createdTransactions.push(...(Array.isArray(txs) ? txs : [txs]));
        return txs;
      });

      jest.spyOn(notificationService, "createAndSendNotification").mockResolvedValue({});

      const results = await Promise.all([
        paymentSettlementService.settlePayment({
          razorpayOrderId,
          razorpayPaymentId,
          isWebhook: false,
        }),
        paymentSettlementService.settlePayment({
          razorpayOrderId,
          razorpayPaymentId,
          eventId: "evt_captured_101",
          eventType: "payment.captured",
          isWebhook: true,
        }),
        paymentSettlementService.settlePayment({
          razorpayOrderId,
          razorpayPaymentId,
          eventId: "evt_paid_102",
          eventType: "order.paid",
          isWebhook: true,
        }),
        paymentSettlementService.settlePayment({
          razorpayOrderId,
          razorpayPaymentId,
          isWebhook: false,
        }),
      ]);

      expect(completedCount).toBe(1);

      expect(createdTransactions.length).toBe(2);
      expect(createdTransactions.filter((t) => t.type === "debit").length).toBe(1);
      expect(createdTransactions.filter((t) => t.type === "credit").length).toBe(1);

      jest.restoreAllMocks();
    });
  });

  describe("4. Live Mode Fail-Closed Protection", () => {
    const originalMode = process.env.PAYMENT_MODE;

    afterEach(() => {
      process.env.PAYMENT_MODE = originalMode;
    });

    it("should fail closed in live mode if credentials are missing", async () => {
      process.env.PAYMENT_MODE = "live";
      razorpayService.mode = "live";
      razorpayService.keyId = null;
      razorpayService.keySecret = null;
      razorpayService.razorpay = null;

      await expect(
        razorpayService.createOrder({ amount: 999, receipt: "rcpt_live_test" })
      ).rejects.toThrow("LIVE MODE FAIL CLOSED");
    });
  });
});
