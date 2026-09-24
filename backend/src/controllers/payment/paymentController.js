const mongoose = require("mongoose");
const Payment = require("../../models/Payment");
const Lawyer = require("../../models/Lawyer");
const Appointment = require("../../models/Appointment");
const Case = require("../../models/Case");
const Transaction = require("../../models/Transaction");
const ApiResponse = require("../../config/ApiResponse");
const notificationService = require("../../services/notification/notificationService");

class PaymentController {
  async createConsultationOrder(req, res, next) {
    try {
      const { lawyerId, appointmentId, caseId } = req.body;
      const clientId = req.user._id;

      if (!lawyerId) {
        return ApiResponse.error(res, "Lawyer ID is required.", 400);
      }

      const lawyer = await Lawyer.findOne({
        $or: [
          { _id: mongoose.Types.ObjectId.isValid(lawyerId) ? lawyerId : null },
          { user: lawyerId },
        ],
      });

      if (!lawyer) {
        return ApiResponse.error(res, "Selected lawyer record was not found.", 404);
      }

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
          return ApiResponse.error(res, "Appointment has already been confirmed.", 400);
        }
        const existingPayment = await Payment.findOne({ appointment: appointmentId, status: "completed" });
        if (existingPayment) {
          return ApiResponse.error(res, "A completed payment already exists for this appointment.", 400);
        }
      }

      if (caseId) {
        const caseDoc = await Case.findById(caseId);
        if (!caseDoc) {
          return ApiResponse.error(res, "Referenced case was not found.", 404);
        }
        if (caseDoc.client.toString() !== clientId.toString()) {
          return ApiResponse.error(res, "Case does not belong to the authenticated client.", 403);
        }
      }

      const fee = lawyer.consultationFee;

      if (!fee || typeof fee !== "number" || fee <= 0) {
        return ApiResponse.error(res, "The selected lawyer has not configured a valid consultation fee.", 400);
      }

      const payment = await Payment.create({
        client: clientId,
        lawyer: lawyer.user,
        amount: fee,
        currency: "INR",
        purpose: "consultation",
        status: "completed",
        paymentMethod: "Free Plan",
        appointment: appointmentId || undefined,
        case: caseId || undefined,
      });

      if (appointmentId) {
        await Appointment.findByIdAndUpdate(appointmentId, { status: "confirmed" });
      }

      const transactionPromises = [
        Transaction.create({
          user: clientId,
          amount: fee,
          type: "debit",
          description: "Consultation Booking (Free Plan)",
          status: "completed",
          payment: payment._id,
        }),
        Transaction.create({
          user: lawyer.user,
          amount: fee,
          type: "credit",
          description: "Consultation booking payment received (Free Plan)",
          status: "completed",
          payment: payment._id,
        }),
      ];

      await Promise.all(transactionPromises);

      const notificationPromises = [
        notificationService.createAndSendNotification({
          receiverId: clientId,
          type: "payment_success",
          title: "Consultation Confirmed",
          message: `Your consultation booking has been confirmed (Free Plan).`,
          referenceId: payment._id.toString(),
        }).catch(() => {}),
        notificationService.createAndSendNotification({
          receiverId: lawyer.user,
          type: "payment_success",
          title: "New Consultation Booking",
          message: `A new consultation booking has been confirmed (Free Plan).`,
          referenceId: payment._id.toString(),
        }).catch(() => {}),
      ];

      Promise.all(notificationPromises);

      return ApiResponse.success(
        res,
        "Consultation booking confirmed successfully.",
        {
          orderId: payment._id,
          amount: fee,
          currency: "INR",
          paymentId: payment._id,
          status: "completed",
        },
        201
      );
    } catch (error) {
      next(error);
    }
  }

  async verifyPayment(req, res, next) {
    try {
      return ApiResponse.success(res, "Payment verification handled server-side.", { status: "completed" });
    } catch (error) {
      next(error);
    }
  }

  async handleWebhook(req, res, next) {
    res.status(200).json({ status: "ok" });
  }

  async getEarnings(req, res, next) {
    try {
      const userId = req.user._id;
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

      const summary = {
        totalEarnings: row("credit")?.settled ?? 0,
        totalWithdrawals: row("withdrawal")?.settled ?? 0,
        pendingWithdrawals: (row("withdrawal")?.total ?? 0) - (row("withdrawal")?.settled ?? 0),
        walletBalance: Math.max(0, (row("credit")?.settled ?? 0) - (row("withdrawal")?.total ?? 0)),
        creditCount: row("credit")?.settledCount ?? 0,
      };

      return ApiResponse.success(res, "Earnings summary fetched.", summary);
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
          },
        },
      ]);

      const row = (type) => ledger.find((entry) => entry._id === type);
      const walletBalance = Math.max(0, (row("credit")?.settled ?? 0) - (row("withdrawal")?.total ?? 0));

      if (Number(amount) > walletBalance) {
        return ApiResponse.error(res, "Insufficient wallet balance.", 400);
      }

      const withdrawalTx = await Transaction.create({
        user: userId,
        amount: Number(amount),
        type: "withdrawal",
        description: "Withdrawal request",
        status: "pending",
      });

      return ApiResponse.success(res, "Withdrawal requested.", withdrawalTx, 201);
    } catch (error) {
      next(error);
    }
  }

  async getTransactions(req, res, next) {
    try {
      const userId = req.user._id;
      const transactions = await Transaction.find({ user: userId }).sort({ createdAt: -1 });
      return ApiResponse.success(res, "Transactions fetched.", transactions);
    } catch (error) {
      next(error);
    }
  }

  async checkout(req, res, next) {
    try {
      const { lawyerId, amount } = req.body;
      const client = req.user._id;

      const payment = await Payment.create({
        client,
        lawyer: lawyerId,
        amount: Number(amount),
        status: "completed",
        paymentMethod: "Free Plan",
      });

      await Transaction.create({
        user: client,
        amount: Number(amount),
        type: "debit",
        description: "Consultation Booking Payment",
        status: "completed",
        payment: payment._id,
      });

      await Transaction.create({
        user: lawyerId,
        amount: Number(amount),
        type: "credit",
        description: "Consultation booking payment received",
        status: "completed",
        payment: payment._id,
      });

      return ApiResponse.success(res, "Booking confirmed.", payment, 201);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PaymentController();
