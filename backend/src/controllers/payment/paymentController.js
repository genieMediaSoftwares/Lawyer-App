const Payment = require("../../models/Payment");
const notificationService = require("../../services/notification/notificationService");
const Transaction = require("../../models/Transaction");
const Appointment = require("../../models/Appointment");
const Lawyer = require("../../models/Lawyer");
const ApiResponse = require("../../config/ApiResponse");

class PaymentController {
  async getEarnings(req, res, next) {
    try {
      const lawyerId = req.user._id;

      // Calculate total earnings from completed appointments
      const lawyerProfile = await Lawyer.findOne({ user: lawyerId });
      const fee = lawyerProfile ? lawyerProfile.consultationFee : 1500;

      const completedAppointments = await Appointment.find({
        lawyer: lawyerId,
        status: "completed",
      });

      const totalCredits = completedAppointments.length * fee;

      // Find total withdrawals
      const withdrawals = await Transaction.find({
        user: lawyerId,
        type: "withdrawal",
        status: "completed",
      });

      const totalWithdrawals = withdrawals.reduce((sum, w) => sum + w.amount, 0);
      const walletBalance = totalCredits - totalWithdrawals;

      return ApiResponse.success(res, "Earnings summary fetched.", {
        totalEarnings: totalCredits,
        walletBalance: walletBalance >= 0 ? walletBalance : 0,
        totalWithdrawals,
        completedConsultationsCount: completedAppointments.length,
      });
    } catch (error) {
      next(error);
    }
  }

  async requestWithdrawal(req, res, next) {
    try {
      const { amount } = req.body;
      const userId = req.user._id;

      if (!amount || amount <= 0) {
        return ApiResponse.error(res, "Invalid withdrawal amount.", 400);
      }

      // Calculate balance
      const lawyerProfile = await Lawyer.findOne({ user: userId });
      const fee = lawyerProfile ? lawyerProfile.consultationFee : 1500;

      const completedAppointments = await Appointment.find({
        lawyer: userId,
        status: "completed",
      });

      const totalCredits = completedAppointments.length * fee;

      const withdrawals = await Transaction.find({
        user: userId,
        type: "withdrawal",
        status: "completed",
      });

      const totalWithdrawals = withdrawals.reduce((sum, w) => sum + w.amount, 0);
      const walletBalance = totalCredits - totalWithdrawals;

      if (amount > walletBalance) {
        return ApiResponse.error(res, "Insufficient wallet balance.", 400);
      }

      const withdrawalTx = await Transaction.create({
        user: userId,
        amount,
        type: "withdrawal",
        description: "Withdrawal to bank account",
        status: "completed", // Instantly approve for simplicity/demo
      });

      return ApiResponse.success(res, "Withdrawal request processed.", withdrawalTx, 201);
    } catch (error) {
      next(error);
    }
  }

  async getTransactions(req, res, next) {
    try {
      const userId = req.user._id;

      // Pull Mongoose transactions
      const dbTx = await Transaction.find({ user: userId }).sort({ createdAt: -1 });

      if (dbTx.length === 0 && req.user.role === "lawyer") {
        // Build mock history based on appointments if no transaction records exist
        const lawyerProfile = await Lawyer.findOne({ user: userId });
        const fee = lawyerProfile ? lawyerProfile.consultationFee : 1500;

        const completedAppointments = await Appointment.find({
          lawyer: userId,
          status: "completed",
        }).populate("client", "fullName");

        const transactionsList = completedAppointments.map((appt) => ({
          _id: appt._id,
          amount: fee,
          type: "credit",
          description: `Consultation fee from ${appt.client ? appt.client.fullName : "Client"}`,
          status: "completed",
          createdAt: appt.updatedAt,
        }));

        return ApiResponse.success(res, "Transactions fetched.", transactionsList);
      }

      return ApiResponse.success(res, "Transactions fetched.", dbTx);
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

      // Create transaction record for client
      await Transaction.create({
        user: client,
        amount,
        type: "debit",
        description: "Consultation Booking Payment",
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
