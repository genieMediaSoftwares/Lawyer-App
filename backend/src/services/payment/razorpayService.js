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

  async createOrder({ amount, currency = "INR", receipt, notes = {} }) {
    if (this.isLiveMode() && !this.razorpay) {
      throw new Error("LIVE MODE FAIL CLOSED: Razorpay credentials missing.");
    }

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

  verifyPaymentSignature({ razorpayOrderId, razorpayPaymentId, razorpaySignature }) {
    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return false;
    }

    if (!this.keySecret) {
      if (this.isLiveMode()) {
        throw new Error("LIVE MODE FAIL CLOSED: RAZORPAY_KEY_SECRET is missing.");
      }
      return razorpaySignature === `mock_sig_${razorpayOrderId}_${razorpayPaymentId}`;
    }

    const generatedSignature = crypto
      .createHmac("sha256", this.keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    return generatedSignature === razorpaySignature;
  }

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

  async fetchPaymentAndOrderDetails(razorpayPaymentId, razorpayOrderId) {
    if (this.razorpay) {
      const payment = await this.razorpay.payments.fetch(razorpayPaymentId);
      const order = await this.razorpay.orders.fetch(razorpayOrderId);
      return {
        paymentStatus: payment.status,
        orderStatus: order.status,
        paymentAmount: payment.amount,
        paymentCurrency: payment.currency,
        orderAmount: order.amount,
        orderCurrency: order.currency,
      };
    }

    if (this.isLiveMode()) {
      throw new Error("LIVE MODE FAIL CLOSED: Cannot fetch Razorpay details without live API keys.");
    }

    return null;
  }
}

module.exports = new RazorpayService();
