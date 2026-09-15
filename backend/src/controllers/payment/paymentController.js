const mongoose = require("mongoose");
const Payment = require("../../models/Payment");
const Lawyer = require("../../models/Lawyer");
const Appointment = require("../../models/Appointment");
const Case = require("../../models/Case");
const Transaction = require("../../models/Transaction");
const ApiResponse = require("../../config/ApiResponse");
const razorpayService = require("../../services/payment/razorpayService");
const paymentSettlementService = require("../../services/payment/paymentSettlementService");

/**
 * A lawyer's balance, derived from the transaction ledger and nothing else.
 */
const walletSummary = async (userId) => {
  const ledger = await Transaction.aggregate([
    {
      $match: {
        user: new mongoose.Types.ObjectId(String(userId)),
        status: { $in: ["pending", "completed"] },
      },
    },
    {
      $group: {
        _id: "$type",
        total: { $sum: "$amount" },
        settled: {
          $sum: { $cond: [{ $eq: ["$status", "completed"] }, "$amount", 0] },
        },
        settledCount: {
          $sum: { $cond: [{ $eq: ["$status", "completed"] }, 1, 0] },
        },
      },
    },
  ]);

  const row = (type) => ledger.find((entry) => entry._id === type);

  const totalEarnings = row("credit")?.settled ?? 0;
  const settledWithdrawals = row("withdrawal")?.settled ?? 0;
  const reservedWithdrawals = row("withdrawal")?.total ?? 0;

  return {
    totalEarnings,
    totalWithdrawals: settledWithdrawals,
    pendingWithdrawals: reservedWithdrawals - settledWithdrawals,
    walletBalance: Math.max(0, totalEarnings - reservedWithdrawals),
    creditCount: row("credit")?.settledCount ?? 0,
  };
};

class PaymentController {
  /**
   * Server-authoritative order creation for consultation payments with strict authorization.
   */
  async createConsultationOrder(req, res, next) {
    try {
      const { lawyerId, appointmentId, caseId } = req.body;
      const clientId = req.user._id;

      if (!lawyerId) {
        return ApiResponse.error(res, "Lawyer ID is required.", 400);
      }

      // Fetch Lawyer record to derive authoritative consultation fee
      const lawyer = await Lawyer.findOne({
        $or: [{ _id: mongoose.Types.ObjectId.isValid(lawyerId) ? lawyerId : null }, { user: lawyerId }],
      });

      if (!lawyer) {
        return ApiResponse.error(res, "Selected lawyer record was not found.", 404);
      }

      // Authorization Check 1: Validate Appointment ownership & re-use if appointmentId supplied
      if (appointmentId) {
        const appointment = await Appointment.findById(appointmentId);
        if (!appointment) {
          return ApiResponse.error(res, "Referenced appointment was not found.", 404);
        }
        if (appointment.client.toString() !== clientId.toString()) {
          return ApiResponse.error(res, "Appointment does not belong to the authenticated client.", 403);
        }
        if (appointment.lawyer.toString() !== lawyer.user.toString()) {
          return ApiResponse.error(res, "Appointment lawyer does not match the selected lawyer.", 400);
        }
        if (appointment.status === "confirmed" || appointment.status === "completed") {
          return ApiResponse.error(res, "Appointment has already been paid for and confirmed.", 400);
        }
        const existingPayment = await Payment.findOne({ appointment: appointmentId, status: "completed" });
        if (existingPayment) {
          return ApiResponse.error(res, "A completed payment already exists for this appointment.", 400);
        }
      }

      // Authorization Check 2: Validate Case ownership if caseId supplied
      if (caseId) {
        const caseDoc = await Case.findById(caseId);
        if (!caseDoc) {
          return ApiResponse.error(res, "Referenced case was not found.", 404);
        }
        if (caseDoc.client.toString() !== clientId.toString()) {
          return ApiResponse.error(res, "Case does not belong to the authenticated client.", 403);
        }
      }

      const authoritativeAmount = lawyer.consultationFee;

      // STRICT MANDATE: Fee MUST come from server-side Lawyer.consultationFee.
      // Missing, null, zero, or negative fee rejects with no Payment/order creation.
      if (!authoritativeAmount || typeof authoritativeAmount !== "number" || authoritativeAmount <= 0) {
        console.warn(
          `[PaymentOrder Rejected] Lawyer User:${lawyer.user} has invalid fee (${authoritativeAmount}). Order creation blocked.`
        );
        return ApiResponse.error(
          res,
          "The selected lawyer has not configured a valid consultation fee.",
          400
        );
      }

      // Create Razorpay Order server-side
      const receipt = `consult_${clientId}_${Date.now()}`;
      const order = await razorpayService.createOrder({
        amount: authoritativeAmount,
        currency: "INR",
        receipt,
        notes: {
          clientId: clientId.toString(),
          lawyerId: lawyer.user.toString(),
          appointmentId: appointmentId || "",
          purpose: "consultation",
        },
      });

      // Create pending Payment record in database
      const payment = await Payment.create({
        client: clientId,
        lawyer: lawyer.user,
        amount: authoritativeAmount,
        currency: "INR",
        purpose: "consultation",
        status: "pending",
        razorpayOrderId: order.id,
        paymentMethod: "Razorpay",
        appointment: appointmentId || undefined,
        case: caseId || undefined,
      });

      return ApiResponse.success(
        res,
        "Consultation payment order created successfully.",
        {
          orderId: order.id,
          amount: authoritativeAmount,
          currency: "INR",
          keyId: razorpayService.keyId || "",
          paymentId: payment._id,
        },
        201
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * Verify Razorpay Payment Signature and Trigger Settlement
   */
  async verifyPayment(req, res, next) {
    try {
      const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

      if (!razorpay_order_id || !razorpay_payment_id) {
        return ApiResponse.error(
          res,
          "razorpay_order_id and razorpay_payment_id are required.",
          400
        );
      }

      const result = await paymentSettlementService.settlePayment({
        razorpayOrderId: razorpay_order_id,
        razorpayPaymentId: razorpay_payment_id,
        razorpaySignature: razorpay_signature,
        isWebhook: false,
      });

      return ApiResponse.success(res, "Payment verified and settled successfully.", result.payment);
    } catch (error) {
      return ApiResponse.error(res, error.message || "Payment verification failed.", 400);
    }
  }

  /**
   * Razorpay Webhook Handler (Handles payment.captured, order.paid, payment.failed)
   */
  async handleWebhook(req, res, next) {
    try {
      const signature = req.headers["x-razorpay-signature"];
      const eventId = req.headers["x-razorpay-event-id"];
      const rawBody = req.rawBody || req.body;

      if (!rawBody) {
        return res.status(400).json({ error: "Missing webhook raw request body." });
      }

      const rawString = Buffer.isBuffer(rawBody) ? rawBody.toString("utf8") : typeof rawBody === "string" ? rawBody : JSON.stringify(rawBody);

      // Signature verification using raw request body
      const isValid = razorpayService.verifyWebhookSignature(rawString, signature);
      if (!isValid) {
        console.warn("[Webhook] Invalid webhook signature received.");
        return res.status(400).json({ error: "Invalid webhook signature." });
      }

      const event = JSON.parse(rawString);
      const eventType = event.event;

      if (eventType === "payment.captured" || eventType === "order.paid") {
        const paymentEntity = event.payload?.payment?.entity || event.payload?.order?.entity;
        const razorpayOrderId = paymentEntity?.order_id || (eventType === "order.paid" ? paymentEntity?.id : null);
        const razorpayPaymentId = paymentEntity?.id || paymentEntity?.payment_id || null;

        if (razorpayOrderId) {
          await paymentSettlementService.settlePayment({
            razorpayOrderId,
            razorpayPaymentId,
            eventId,
            eventType,
            isWebhook: true,
          });
        }
      } else if (eventType === "payment.failed") {
        const paymentEntity = event.payload?.payment?.entity;
        if (paymentEntity && paymentEntity.order_id) {
          await paymentSettlementService.handlePaymentFailure({
            razorpayOrderId: paymentEntity.order_id,
            razorpayPaymentId: paymentEntity.id,
            eventId,
            errorMessage: paymentEntity.error_description || "Payment failed",
          });
        }
      }

      return res.status(200).json({ status: "ok" });
    } catch (error) {
      console.error("[Webhook Processing Error]", error);
      return res.status(500).json({ error: error.message || "Webhook processing failed." });
    }
  }

  async getEarnings(req, res, next) {
    try {
      const summary = await walletSummary(req.user._id);

      return ApiResponse.success(res, "Earnings summary fetched.", {
        totalEarnings: summary.totalEarnings,
        walletBalance: summary.walletBalance,
        totalWithdrawals: summary.totalWithdrawals,
        completedConsultationsCount: summary.creditCount,
      });
    } catch (error) {
      next(error);
    }
  }

  async requestWithdrawal(req, res, next) {
    try {
      const { amount } = req.body;
      const userId = req.user._id;

      if (!amount || !Number.isFinite(Number(amount)) || Number(amount) <= 0) {
        return ApiResponse.error(res, "Invalid withdrawal amount.", 400);
      }

      const { walletBalance } = await walletSummary(userId);

      if (Number(amount) > walletBalance) {
        return ApiResponse.error(res, "Insufficient wallet balance.", 400);
      }

      const withdrawalTx = await Transaction.create({
        user: userId,
        amount: Number(amount),
        type: "withdrawal",
        description: "Withdrawal to bank account",
        status: "pending",
      });

      return ApiResponse.success(
        res,
        "Withdrawal requested. It will be credited to your bank account once processed.",
        withdrawalTx,
        201
      );
    } catch (error) {
      next(error);
    }
  }

  async getTransactions(req, res, next) {
    try {
      const userId = req.user._id;

      const transactions = await Transaction.find({ user: userId }).sort({
        createdAt: -1,
      });

      return ApiResponse.success(res, "Transactions fetched.", transactions);
    } catch (error) {
      next(error);
    }
  }

  async checkout(req, res, next) {
    try {
      if (process.env.PAYMENT_MODE === "live") {
        return ApiResponse.error(
          res,
          "LIVE MODE PROTECTION: Untransactional direct checkout disabled. Use server order creation via /api/payments/create-consultation-order.",
          400
        );
      }

      const { lawyerId, amount, paymentMethod } = req.body;
      const client = req.user._id;

      const payment = await Payment.create({
        client,
        lawyer: lawyerId,
        amount,
        status: "completed",
        paymentMethod: paymentMethod || "Card",
      });

      await Transaction.create({
        user: client,
        amount,
        type: "debit",
        description: "Consultation Booking Payment",
        status: "completed",
      });

      await Transaction.create({
        user: lawyerId,
        amount,
        type: "credit",
        description: "Consultation booking payment received",
        status: "completed",
      });

      return ApiResponse.success(res, "Checkout payment created.", payment, 201);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PaymentController();
