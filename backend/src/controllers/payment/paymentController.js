const mongoose = require("mongoose");
const Payment = require("../../models/Payment");
const notificationService = require("../../services/notification/notificationService");
const Transaction = require("../../models/Transaction");
const ApiResponse = require("../../config/ApiResponse");

/**
 * A lawyer's balance, derived from the transaction ledger and nothing else.
 *
 * Both endpoints below used to compute this as
 * `completedAppointments.length * lawyer.consultationFee`, falling back to a
 * hardcoded ₹1500 when the lawyer had not set a fee. That figure was never
 * money that had actually moved: it counted appointments rather than payments,
 * it re-priced historic consultations whenever a lawyer edited their fee, and
 * it credited consultations that were never paid for. Withdrawals were then
 * authorised against it.
 */
const walletSummary = async (userId) => {
  const ledger = await Transaction.aggregate([
    {
      $match: {
        user: new mongoose.Types.ObjectId(String(userId)),
        // A withdrawal reserves funds the moment it is requested, so pending
        // ones count against the balance too. Counting only "completed" would
        // let a lawyer request their full balance repeatedly while earlier
        // payouts were still in flight.
        status: { $in: ["pending", "completed"] },
      },
    },
    {
      $group: {
        _id: "$type",
        total: { $sum: "$amount" },
        // Earnings and the consultation count are what has actually settled.
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
  async getEarnings(req, res, next) {
    try {
      const summary = await walletSummary(req.user._id);

      return ApiResponse.success(res, "Earnings summary fetched.", {
        totalEarnings: summary.totalEarnings,
        walletBalance: summary.walletBalance,
        totalWithdrawals: summary.totalWithdrawals,
        // The number of consultations actually paid for, which is what the
        // earnings figure is built from.
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

      // Recorded as pending: the money has not left the platform until a payout
      // is actually executed and confirmed. Marking it "completed" on creation
      // meant the balance dropped for a transfer that had not happened, and
      // there was no state left to represent a payout that later failed.
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

      // Only real Transaction records, always.
      //
      // A lawyer with no transactions used to be served a synthesised history
      // instead: one fabricated "credit" per completed appointment, priced at
      // their current consultation fee (or a hardcoded ₹1500 if they had not
      // set one), carrying the appointment's id as a transaction id and its
      // updatedAt as a settlement date. None of it existed in the ledger, so
      // the earnings shown never reconciled against a withdrawal, and the
      // figures changed retroactively whenever a lawyer edited their fee.
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
      const { lawyerId, amount, paymentMethod } = req.body;
      const client = req.user._id;

      const payment = await Payment.create({
        client,
        lawyer: lawyerId,
        amount,
        status: "completed",
        paymentMethod: paymentMethod || "Card",
      });

      // Double-entry: the client is debited and the lawyer credited, in one
      // place, for the same payment.
      //
      // Only the debit used to be written. With no matching credit, a lawyer's
      // ledger was permanently empty, which is why the earnings and withdrawal
      // endpoints reconstructed a balance from `completedAppointments.length *
      // currentConsultationFee` instead. That estimate drifted from what was
      // actually paid the moment a lawyer changed their fee.
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

      // Send notifications to client & lawyer
      await notificationService.createAndSendNotification({
        receiverId: client,
        type: "payment_success",
        title: "Payment Successful",
        message: `Your payment of ₹${amount} was processed successfully.`,
        referenceId: payment._id.toString()
      });

      await notificationService.createAndSendNotification({
        receiverId: lawyerId,
        type: "payment_success",
        title: "Payment Received",
        message: `You have received a payment of ₹${amount} for a consultation booking.`,
        referenceId: payment._id.toString()
      });

      return ApiResponse.success(res, "Checkout payment created.", payment, 201);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PaymentController();
