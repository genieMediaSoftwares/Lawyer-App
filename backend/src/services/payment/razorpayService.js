const Razorpay = require("razorpay");
const crypto = require("crypto");

class RazorpayService {
  constructor() {
    this.mode = process.env.PAYMENT_MODE || "sandbox";
    this.keyId = process.env.RAZORPAY_KEY_ID;
    this.keySecret = process.env.RAZORPAY_KEY_SECRET;
    this.webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;

    if (this.mode === "live") {
      if (!this.keyId || !this.keySecret) {
        throw new Error("LIVE MODE FAIL CLOSED: RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are required in live mode.");
      }
    }

    if (this.keyId && this.keySecret) {
      this.razorpay = new Razorpay({
        key_id: this.keyId,
        key_secret: this.keySecret,
      });
    } else {
      this.razorpay = null;
    }
  }

  isLiveMode() {
    return this.mode === "live";
  }

  /**
   * Create a Razorpay Order server-side.
   * @param {Object} options - { amount: Number (in INR), currency: 'INR', receipt: String, notes: Object }
   * @returns {Promise<Object>} Razorpay order object
   */
  async createOrder({ amount, currency = "INR", receipt, notes = {} }) {
    if (this.isLiveMode() && !this.razorpay) {
      throw new Error("LIVE MODE FAIL CLOSED: Razorpay credentials missing.");
    }

    // Convert amount in INR rupees to paise (integer)
    const amountInPaise = Math.round(amount * 100);

    if (this.razorpay) {
      const order = await this.razorpay.orders.create({
        amount: amountInPaise,
        currency,
        receipt,
        notes,
      });
      return {
        id: order.id,
        amount: order.amount,
        currency: order.currency,
        receipt: order.receipt,
        status: order.status,
      };
    }

    // Sandbox/Test fallback when SDK credentials are not configured in test environment
    if (this.mode === "live") {
      throw new Error("LIVE MODE FAIL CLOSED: Cannot create order without valid live credentials.");
    }

    const mockOrderId = "order_mock_" + crypto.randomBytes(8).toString("hex");
    return {
      id: mockOrderId,
      amount: amountInPaise,
      currency,
      receipt,
      status: "created",
    };
  }

  /**
   * Verify Razorpay Payment Signature for client checkout.
   * HMAC SHA256 of `order_id|payment_id` using RAZORPAY_KEY_SECRET.
   */
  verifyPaymentSignature({ razorpayOrderId, razorpayPaymentId, razorpaySignature }) {
    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return false;
    }

    if (!this.keySecret) {
      if (this.isLiveMode()) {
        throw new Error("LIVE MODE FAIL CLOSED: RAZORPAY_KEY_SECRET is missing.");
      }
      // In sandbox mode without credentials, accept mock signatures generated for testing
      return razorpaySignature === `mock_sig_${razorpayOrderId}_${razorpayPaymentId}`;
    }

    const generatedSignature = crypto
      .createHmac("sha256", this.keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    return generatedSignature === razorpaySignature;
  }

  /**
   * Verify Razorpay Webhook Signature using raw request body.
   */
  verifyWebhookSignature(rawBody, signature) {
    if (!signature) return false;
    const secret = this.webhookSecret || this.keySecret;
    if (!secret) {
      if (this.isLiveMode()) {
        throw new Error("LIVE MODE FAIL CLOSED: Webhook secret missing in live mode.");
      }
      return signature === "mock_webhook_signature";
    }

    const expectedSignature = crypto
      .createHmac("sha256", secret)
      .update(rawBody)
      .digest("hex");

    return expectedSignature === signature;
  }

  /**
   * Fetch payment and order status directly from Razorpay API when credentials are present.
   */
  async fetchPaymentAndOrderDetails(razorpayPaymentId, razorpayOrderId) {
    if (this.razorpay) {
      const payment = await this.razorpay.payments.fetch(razorpayPaymentId);
      const order = await this.razorpay.orders.fetch(razorpayOrderId);
      return {
        paymentStatus: payment.status, // expected: 'captured'
        orderStatus: order.status,     // expected: 'paid'
        paymentAmount: payment.amount, // in paise
        paymentCurrency: payment.currency,
        orderAmount: order.amount,     // in paise
        orderCurrency: order.currency,
      };
    }

    // In sandbox without API keys, return mock details matching expected captured/paid
    if (this.isLiveMode()) {
      throw new Error("LIVE MODE FAIL CLOSED: Cannot fetch Razorpay details without live API keys.");
    }

    return null; // Signals controller/settlement service that live SDK fetch was skipped in test mock mode
  }
}

module.exports = new RazorpayService();
