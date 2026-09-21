const mongoose = require("mongoose");
const Payment = require("../../models/Payment");
const Transaction = require("../../models/Transaction");
const Subscription = require("../../models/Subscription");
const Lawyer = require("../../models/Lawyer");
const Appointment = require("../../models/Appointment");
const WebhookEvent = require("../../models/WebhookEvent");
const razorpayService = require("./razorpayService");
const notificationService = require("../notification/notificationService");
const { runInTransaction } = require("../../utils/dbTransaction");

class PaymentSettlementService {
  /**
   * Single idempotent ACID settlement logic for payment verification & webhook events.
   *
   * @param {Object} params
   * @param {String} params.razorpayOrderId
   * @param {String} params.razorpayPaymentId
   * @param {String} [params.razorpaySignature]
   * @param {String} [params.eventId] - x-razorpay-event-id for webhook idempotency
   * @param {String} [params.eventType]
   * @param {Boolean} [params.isWebhook]
   * @returns {Promise<Object>} Settlement result
   */
  async settlePayment({
    razorpayOrderId,
    razorpayPaymentId,
    razorpaySignature,
    eventId,
    eventType = "payment.captured",
    isWebhook = false,
  }) {
    if (!razorpayOrderId) {
      throw new Error("Razorpay Order ID is required for payment settlement.");
    }

    // 1. Webhook Event Idempotency & Deduplication Check
    if (isWebhook && eventId) {
      const existingEvent = await WebhookEvent.findOne({ eventId });
      if (existingEvent) {
        if (existingEvent.status === "processed") {
          const existingPayment = await Payment.findOne({ razorpayOrderId });
          return {
            status: "already_processed_webhook",
            eventId,
            payment: existingPayment,
          };
        }
        // If event status is 'processing' or 'failed', allow execution/retry
      } else {
        await WebhookEvent.create({
          eventId,
          eventType,
          status: "processing",
        });
      }
    }

    try {
      // 2. Fetch Payment record by razorpayOrderId (server-stored order ID)
      const payment = await Payment.findOne({ razorpayOrderId });
      if (!payment) {
        throw new Error(`Payment record not found for Razorpay order ID: ${razorpayOrderId}`);
      }

      // 3. Early Idempotency Check on Payment status
      if (payment.status === "completed") {
        if (isWebhook && eventId) {
          await WebhookEvent.updateOne({ eventId }, { status: "processed", processedAt: new Date() });
        }
        return {
          status: "already_completed",
          payment,
        };
      }

      // 4. Signature Verification (Uses server-stored razorpayOrderId)
      if (razorpaySignature) {
        const isValid = razorpayService.verifyPaymentSignature({
          razorpayOrderId: payment.razorpayOrderId,
          razorpayPaymentId,
          razorpaySignature,
        });
        if (!isValid) {
          throw new Error("Invalid Razorpay payment signature.");
        }
      }

      // 5. Fetch and Verify directly from Razorpay API when credentials are present
      const razorpayDetails = await razorpayService.fetchPaymentAndOrderDetails(
        razorpayPaymentId,
        payment.razorpayOrderId
      );

      if (razorpayDetails) {
        if (razorpayDetails.paymentStatus !== "captured") {
          throw new Error(`Razorpay payment status is '${razorpayDetails.paymentStatus}', expected 'captured'.`);
        }
        if (razorpayDetails.orderStatus !== "paid") {
          throw new Error(`Razorpay order status is '${razorpayDetails.orderStatus}', expected 'paid'.`);
        }

        // Amount verification (razorpayDetails amounts are in paise)
        const expectedPaise = Math.round(payment.amount * 100);
        if (razorpayDetails.paymentAmount !== expectedPaise || razorpayDetails.orderAmount !== expectedPaise) {
          throw new Error(
            `Payment amount mismatch. Expected: ${expectedPaise} paise, Razorpay Payment: ${razorpayDetails.paymentAmount}, Order: ${razorpayDetails.orderAmount}`
          );
        }

        // Currency verification
        if (
          razorpayDetails.paymentCurrency !== payment.currency ||
          razorpayDetails.orderCurrency !== payment.currency
        ) {
          throw new Error(
            `Currency mismatch. Expected: ${payment.currency}, Razorpay Payment: ${razorpayDetails.paymentCurrency}, Order: ${razorpayDetails.orderCurrency}`
          );
        }
      }

      // 6. Execute Single MongoDB ACID Transaction for status change + ledger + state updates
      let updatedPayment = null;
      let notificationPayloads = [];

      const executeSettlement = async (session) => {
        // ATOMIC DB-LEVEL IDEMPOTENCY: findOneAndUpdate with status: { $ne: "completed" }
        // Guarantees only one concurrent worker can transition state!
        const currentPayment = await Payment.findOneAndUpdate(
          { _id: payment._id, status: { $ne: "completed" } },
          {
            $set: {
              status: "completed",
              razorpayPaymentId: razorpayPaymentId || payment.razorpayPaymentId,
              ...(razorpaySignature ? { razorpaySignature } : {}),
            },
          },
          { new: true, session: session || null }
        );

        if (!currentPayment) {
          // Concurrently settled by another worker
          const existing = session
            ? await Payment.findById(payment._id).session(session)
            : await Payment.findById(payment._id);
          return { status: "already_completed", payment: existing };
        }

        if (currentPayment.purpose === "consultation") {
          // Double-entry financial ledger: Client debit, Lawyer credit
          await Transaction.create(
            [
              {
                user: currentPayment.client,
                amount: currentPayment.amount,
                type: "debit",
                description: "Consultation Booking Payment",
                status: "completed",
              },
              {
                user: currentPayment.lawyer,
                amount: currentPayment.amount,
                type: "credit",
                description: "Consultation booking payment received",
                status: "completed",
              },
            ],
            session ? { session } : {}
          );

          // Update associated Appointment status if present
          if (currentPayment.appointment) {
            await Appointment.updateOne(
              { _id: currentPayment.appointment },
              { status: "confirmed" },
              session ? { session } : {}
            );
          }

          notificationPayloads.push({
            receiverId: currentPayment.client,
            type: "payment_success",
            title: "Payment Successful",
            message: `Your payment of ₹${currentPayment.amount} for consultation was processed successfully.`,
            referenceId: currentPayment._id.toString(),
          });

          notificationPayloads.push({
            receiverId: currentPayment.lawyer,
            type: "payment_success",
            title: "Payment Received",
            message: `You received a consultation payment of ₹${currentPayment.amount}.`,
            referenceId: currentPayment._id.toString(),
          });
        } else if (currentPayment.purpose === "subscription") {
          // Subscription Payment - Subscription owner is currentPayment.lawyer (authenticated Lawyer)
          const lawyerUser = currentPayment.lawyer;

          await Transaction.create(
            [
              {
                user: lawyerUser,
                amount: currentPayment.amount,
                type: "debit",
                description: `Lawfly Subscription Payment (${currentPayment.subscriptionPlan})`,
                status: "completed",
              },
            ],
            session ? { session } : {}
          );

          // Atomically expire previous active subscriptions for this lawyer
          await Subscription.updateMany(
            { user: lawyerUser, status: "active" },
            { status: "expired" },
            session ? { session } : {}
          );

          // Create new 30-day active Subscription
          const startDate = new Date();
          const endDate = new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000);

          await Subscription.create(
            [
              {
                user: lawyerUser,
                plan: currentPayment.subscriptionPlan,
                status: "active",
                startDate,
                endDate,
              },
            ],
            session ? { session } : {}
          );

          // Update Lawyer profile subscriptionPlan
          await Lawyer.updateOne(
            { user: lawyerUser },
            { subscriptionPlan: currentPayment.subscriptionPlan },
            session ? { session } : {}
          );

          notificationPayloads.push({
            receiverId: lawyerUser,
            type: "subscription_success",
            title: "Subscription Activated",
            message: `Your ${currentPayment.subscriptionPlan} subscription (₹${currentPayment.amount}) is now active for 30 days.`,
            referenceId: currentPayment._id.toString(),
          });
        }

        return { status: "settled", payment: currentPayment };
      };

      const result = await runInTransaction(executeSettlement);
      updatedPayment = result.payment || payment;

      // 7. Mark Webhook Event as PROCESSED only AFTER successful business settlement
      if (isWebhook && eventId) {
        await WebhookEvent.updateOne(
          { eventId },
          { status: "processed", processedAt: new Date() }
        );
      }

      // 8. Trigger notifications ONLY AFTER successful DB commit
      for (const notif of notificationPayloads) {
        try {
          await notificationService.createAndSendNotification(notif);
        } catch (err) {
          console.error("[Post-Commit Notification Error]", err);
        }
      }

      return {
        status: "success",
        payment: updatedPayment,
      };
    } catch (error) {
      // If settlement failed, mark WebhookEvent as 'failed' so Razorpay retries can re-attempt
      if (isWebhook && eventId) {
        await WebhookEvent.updateOne(
          { eventId },
          { status: "failed", errorMessage: error.message }
        );
      }
      throw error;
    }
  }

  /**
   * Handle Razorpay payment.failed webhook event.
   */
  async handlePaymentFailure({ razorpayOrderId, razorpayPaymentId, eventId, errorMessage }) {
    if (eventId) {
      await WebhookEvent.create({
        eventId,
        eventType: "payment.failed",
        status: "processed",
        errorMessage,
        processedAt: new Date(),
      }).catch(() => {});
    }

    if (razorpayOrderId) {
      await Payment.updateOne(
        { razorpayOrderId, status: "pending" },
        { status: "failed", razorpayPaymentId }
      );
    }
    return { status: "failed_recorded" };
  }
}

module.exports = new PaymentSettlementService();
