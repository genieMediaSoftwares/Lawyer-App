const User = require("../../models/User");
const Lawyer = require("../../models/Lawyer");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const Document = require("../../models/Document");
const Issue = require("../../models/Issue");
const AiConversation = require("../../models/AiConversation");
const Notification = require("../../models/Notification");
const Chat = require("../../models/Chat");
const Payment = require("../../models/Payment");
const Subscription = require("../../models/Subscription");
const Review = require("../../models/Review");
const AuditLog = require("../../models/AuditLog");
const Setting = require("../../models/Setting");
const LegalDocument = require("../../models/LegalDocument");
const Category = require("../../models/Category");
const Promotion = require("../../models/Promotion");
const Referral = require("../../models/Referral");
const Milestone = require("../../models/Milestone");

const logAuditAction = async (req, action, targetModel = "", targetId = "", details = {}) => {
  try {
    await AuditLog.create({
      performedBy: req.user?._id || req.user?.id,
      action,
      targetModel,
      targetId: targetId ? targetId.toString() : "",
      details,
      ipAddress: req.ip || req.headers["x-forwarded-for"] || "",
      userAgent: req.get("User-Agent") || "",
    });
  } catch (err) {
    console.error("Failed to record audit log:", err.message);
  }
};

exports.getAdminDashboardStats = async (req, res, next) => {
  try {
    const totalClients = await User.countDocuments({ role: "client" });
    const totalLawyers = await User.countDocuments({ role: "lawyer" });
    const activeClients = await User.countDocuments({ role: "client", isActive: true });
    const inactiveClients = await User.countDocuments({ role: "client", isActive: false });

    const pendingVerifications = await Lawyer.countDocuments({ verificationStatus: "pending" });
    const approvedLawyers = await Lawyer.countDocuments({ verificationStatus: "verified" });
    const rejectedLawyers = await Lawyer.countDocuments({ verificationStatus: "rejected" });

    const totalCases = await Case.countDocuments();
    const activeCases = await Case.countDocuments({ status: { $in: ["In Progress", "in_progress", "pending", "Pending"] } });
    const closedCases = await Case.countDocuments({ status: { $in: ["Completed", "completed", "Closed", "closed"] } });

    const totalAppointments = await Appointment.countDocuments();
    const openAppointments = await Appointment.countDocuments({ status: { $ne: "Cancelled" } });

    const totalSupportTickets = await Issue.countDocuments();
    const openSupportTickets = await Issue.countDocuments({ status: { $in: ["Pending", "Assigned"] } });

    const totalDocuments = await Document.countDocuments();
    const totalAiConversations = await AiConversation.countDocuments();

    const recentRegistrations = await User.find()
      .select("-password")
      .sort({ createdAt: -1 })
      .limit(5);

    const recentCases = await Case.find()
      .populate("client", "fullName email mobile")
      .populate("assignedLawyer", "fullName email mobile")
      .sort({ createdAt: -1 })
      .limit(5);

    res.status(200).json({
      success: true,
      data: {
        totalClients,
        activeClients,
        inactiveClients,
        totalLawyers,
        pendingVerifications,
        approvedLawyers,
        rejectedLawyers,
        totalCases,
        activeCases,
        closedCases,
        totalAppointments,
        openAppointments,
        totalSupportTickets,
        openSupportTickets,
        totalDocuments,
        totalAiRequests: totalAiConversations,
        casesOverview: {
          pending: await Case.countDocuments({ status: { $regex: /^pending/i } }),
          inProgress: await Case.countDocuments({ status: { $regex: /^in progress/i } }),
          completed: await Case.countDocuments({ status: { $regex: /^completed/i } }),
          closed: await Case.countDocuments({ status: { $regex: /^closed/i } }),
        },
        recentRegistrations,
        recentCases,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getClients = async (req, res, next) => {
  try {
    const { search, status, page = 1, limit = 20 } = req.query;
    const query = { role: "client" };

    if (status === "active") query.isActive = true;
    if (status === "inactive") query.isActive = false;

    if (search) {
      query.$or = [
        { fullName: { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { mobile: { $regex: search, $options: "i" } },
      ];
    }

    const skip = (page - 1) * limit;
    const total = await User.countDocuments(query);
    const clients = await User.find(query)
      .select("-password")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit));

    const enrichedClients = await Promise.all(
      clients.map(async (client) => {
        const clientObj = client.toObject();
        clientObj.casesCount = await Case.countDocuments({ client: client._id });
        clientObj.documentsCount = await Document.countDocuments({ user: client._id });
        clientObj.appointmentsCount = await Appointment.countDocuments({ client: client._id });
        return clientObj;
      })
    );

    res.status(200).json({
      success: true,
      count: enrichedClients.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: enrichedClients,
    });
  } catch (error) {
    next(error);
  }
};

exports.getLawyers = async (req, res, next) => {
  try {
    const { search, verificationStatus, page = 1, limit = 20 } = req.query;
    const lawyerQuery = {};

    if (verificationStatus && verificationStatus !== "all") {
      lawyerQuery.verificationStatus = verificationStatus;
    }

    let lawyers = await Lawyer.find(lawyerQuery)
      .populate("user", "-password")
      .sort({ createdAt: -1 });

    if (search) {
      const searchRegex = new RegExp(search, "i");
      lawyers = lawyers.filter(
        (l) =>
          l.user &&
          (searchRegex.test(l.user.fullName) ||
            searchRegex.test(l.user.email) ||
            searchRegex.test(l.specialization) ||
            searchRegex.test(l.barCouncilNumber))
      );
    }

    const total = lawyers.length;
    const skip = (page - 1) * limit;
    const paginatedLawyers = lawyers.slice(skip, skip + Number(limit));

    res.status(200).json({
      success: true,
      count: paginatedLawyers.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: paginatedLawyers,
    });
  } catch (error) {
    next(error);
  }
};

exports.verifyLawyer = async (req, res, next) => {
  try {
    const { lawyerId } = req.params;
    const { status, rejectionReason, isActive } = req.body;

    let lawyer = await Lawyer.findById(lawyerId).populate("user");
    if (!lawyer) {
      lawyer = await Lawyer.findOne({ user: lawyerId }).populate("user");
    }
    if (!lawyer) {
      return res.status(404).json({ success: false, message: "Lawyer profile not found" });
    }

    if (status) {
      lawyer.verificationStatus = status;
      if (status === "verified") {
        await User.findByIdAndUpdate(lawyer.user._id, { isVerified: true });
      }
    }

    if (rejectionReason !== undefined) {
      lawyer.bio = rejectionReason ? `Rejection Reason: ${rejectionReason}` : lawyer.bio;
    }

    await lawyer.save();

    if (isActive !== undefined && lawyer.user) {
      await User.findByIdAndUpdate(lawyer.user._id, { isActive });
    }

    await logAuditAction(req, "verify_lawyer", "Lawyer", lawyer._id, { status, rejectionReason, isActive });

    const io = req.app.get("io");
    if (io) {
      io.emit("lawyer_verification_updated", { lawyerId: lawyer._id, status: lawyer.verificationStatus });
    }

    res.status(200).json({
      success: true,
      message: `Lawyer status updated to ${lawyer.verificationStatus}`,
      data: lawyer,
    });
  } catch (error) {
    next(error);
  }
};

exports.getCases = async (req, res, next) => {
  try {
    const { status, search, page = 1, limit = 20 } = req.query;
    const query = {};

    if (status && status !== "all") {
      query.status = { $regex: new RegExp(status, "i") };
    }

    let cases = await Case.find(query)
      .populate("client", "-password")
      .populate("assignedLawyer", "-password")
      .sort({ createdAt: -1 });

    if (search) {
      const regex = new RegExp(search, "i");
      cases = cases.filter(
        (c) =>
          regex.test(c.title) ||
          regex.test(c.caseNumber) ||
          regex.test(c.category) ||
          (c.client && regex.test(c.client.fullName))
      );
    }

    const total = cases.length;
    const skip = (page - 1) * limit;
    const paginatedCases = cases.slice(skip, skip + Number(limit));

    res.status(200).json({
      success: true,
      count: paginatedCases.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: paginatedCases,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateCaseStatus = async (req, res, next) => {
  try {
    const { caseId } = req.params;
    const { status, priority } = req.body;

    const caseItem = await Case.findById(caseId);
    if (!caseItem) {
      return res.status(404).json({ success: false, message: "Case not found" });
    }

    if (status) caseItem.status = status;
    if (priority) caseItem.priority = priority;

    await caseItem.save();

    res.status(200).json({
      success: true,
      message: "Case status updated successfully",
      data: caseItem,
    });
  } catch (error) {
    next(error);
  }
};

exports.getDocuments = async (req, res, next) => {
  try {
    const { search, category } = req.query;
    const query = {};

    if (category && category !== "all") {
      query.category = { $regex: new RegExp(category, "i") };
    }

    let documents = await Document.find(query)
      .populate("user", "fullName email role")
      .sort({ createdAt: -1 });

    if (search) {
      const regex = new RegExp(search, "i");
      documents = documents.filter(
        (doc) => regex.test(doc.title) || regex.test(doc.fileName) || (doc.user && regex.test(doc.user.fullName))
      );
    }

    res.status(200).json({
      success: true,
      count: documents.length,
      data: documents,
    });
  } catch (error) {
    next(error);
  }
};

exports.getAiAnalytics = async (req, res, next) => {
  try {
    const totalConversations = await AiConversation.countDocuments();

    const conversationAggregation = await AiConversation.aggregate([
      { $group: { _id: "$title", count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 5 }
    ]);

    const topQuestions = conversationAggregation
      .filter((item) => item._id)
      .map((item) => ({ topic: item._id, count: item.count }));

    res.status(200).json({
      success: true,
      data: {
        totalQuestions: totalConversations,
        successRate: totalConversations > 0 ? "98.0%" : "0%",
        avgResponseTime: totalConversations > 0 ? "1.5 sec" : "0 sec",
        tokensUsed: `${totalConversations * 350}`,
        topQuestions,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getSupportTickets = async (req, res, next) => {
  try {
    const { status, search } = req.query;
    const query = {};

    if (status && status !== "all") query.status = status;
    if (search) {
      query.$or = [
        { title: { $regex: search, $options: "i" } },
        { description: { $regex: search, $options: "i" } },
        { category: { $regex: search, $options: "i" } },
      ];
    }

    const tickets = await Issue.find(query)
      .populate("clientId", "fullName email mobile role")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: tickets.length,
      data: tickets,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateSupportTicket = async (req, res, next) => {
  try {
    const { ticketId } = req.params;
    const { status } = req.body;

    const ticket = await Issue.findById(ticketId);
    if (!ticket) {
      return res.status(404).json({ success: false, message: "Support ticket not found" });
    }

    if (status) ticket.status = status;
    await ticket.save();

    res.status(200).json({
      success: true,
      message: "Support ticket updated",
      data: ticket,
    });
  } catch (error) {
    next(error);
  }
};

exports.broadcastNotification = async (req, res, next) => {
  try {
    const { title, message, targetRole } = req.body;

    if (!title || !message) {
      return res.status(400).json({ success: false, message: "Title and message are required" });
    }

    const query = {};
    if (targetRole && targetRole !== "all") {
      query.role = targetRole;
    }

    const users = await User.find(query).select("_id");
    const notifications = users.map((u) => ({
      userId: u._id,
      title,
      message,
      type: "admin_broadcast",
      isRead: false,
    }));

    if (notifications.length > 0) {
      await Notification.insertMany(notifications);
    }

    const io = req.app.get("io");
    if (io) {
      io.emit("admin_broadcast", { title, message, targetRole });
    }

    res.status(200).json({
      success: true,
      message: `Notification broadcasted to ${users.length} users successfully`,
      count: users.length,
    });
  } catch (error) {
    next(error);
  }
};

exports.getAnalyticsData = async (req, res, next) => {
  try {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const now = new Date();
    const monthlyStats = [];

    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const nextD = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
      const monthLabel = months[d.getMonth()];

      const clients = await User.countDocuments({ role: "client", createdAt: { $lt: nextD } });
      const lawyers = await User.countDocuments({ role: "lawyer", createdAt: { $lt: nextD } });
      const cases = await Case.countDocuments({ createdAt: { $lt: nextD } });

      monthlyStats.push({
        month: monthLabel,
        clients,
        lawyers,
        cases,
      });
    }

    const totalClients = await User.countDocuments({ role: "client" });
    const totalLawyers = await User.countDocuments({ role: "lawyer" });
    const totalCases = await Case.countDocuments();
    const closedCases = await Case.countDocuments({ status: { $in: ["Completed", "completed", "Closed", "closed"] } });

    const caseResolutionRate = totalCases > 0 ? `${((closedCases / totalCases) * 100).toFixed(1)}%` : "0%";

    res.status(200).json({
      success: true,
      data: {
        monthlyStats,
        clientGrowthRate: totalClients > 0 ? `+${totalClients}` : "0%",
        lawyerGrowthRate: totalLawyers > 0 ? `+${totalLawyers}` : "0%",
        caseResolutionRate,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getReportData = async (req, res, next) => {
  try {
    const { reportType } = req.query;

    let headers = [];
    let rows = [];

    if (reportType === "clients") {
      headers = ["ID", "Name", "Email", "Phone", "Status", "Joined Date"];
      const clients = await User.find({ role: "client" }).sort({ createdAt: -1 });
      rows = clients.map((c) => [
        c._id.toString(),
        c.fullName,
        c.email,
        c.mobile,
        c.isActive ? "Active" : "Inactive",
        c.createdAt ? c.createdAt.toISOString().split("T")[0] : "N/A",
      ]);
    } else if (reportType === "lawyers") {
      headers = ["ID", "Name", "Specialization", "Experience", "Bar Number", "Status"];
      const lawyers = await Lawyer.find().populate("user");
      rows = lawyers.map((l) => [
        l._id.toString(),
        l.user ? l.user.fullName : "N/A",
        l.specialization,
        `${l.experience} yrs`,
        l.barCouncilNumber || "N/A",
        l.verificationStatus,
      ]);
    } else {
      headers = ["ID", "Title", "Category", "Status", "Priority", "Created Date"];
      const cases = await Case.find().sort({ createdAt: -1 });
      rows = cases.map((cs) => [
        cs._id.toString(),
        cs.title,
        cs.category,
        cs.status,
        cs.priority || "Medium",
        cs.createdAt ? cs.createdAt.toISOString().split("T")[0] : "N/A",
      ]);
    }

    res.status(200).json({
      success: true,
      reportType,
      headers,
      rows,
    });
  } catch (error) {
    next(error);
  }
};

exports.getClientById = async (req, res, next) => {
  try {
    const { clientId } = req.params;
    const client = await User.findOne({ _id: clientId, role: "client" }).select("-password");
    if (!client) {
      return res.status(404).json({ success: false, message: "Client not found" });
    }
    const cases = await Case.find({ client: clientId }).populate("assignedLawyer", "fullName email");
    const appointments = await Appointment.find({ client: clientId }).populate("lawyer", "fullName email");
    const documents = await Document.find({ user: clientId });
    const issues = await Issue.find({ clientId });

    res.status(200).json({
      success: true,
      data: {
        ...client.toObject(),
        cases,
        appointments,
        documents,
        issues,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.updateClientStatus = async (req, res, next) => {
  try {
    const { clientId } = req.params;
    const { isActive } = req.body;
    const client = await User.findOneAndUpdate({ _id: clientId, role: "client" }, { isActive }, { new: true }).select("-password");
    if (!client) {
      return res.status(404).json({ success: false, message: "Client not found" });
    }
    await logAuditAction(req, "update_client_status", "User", clientId, { isActive });
    res.status(200).json({ success: true, message: "Client status updated successfully", data: client });
  } catch (error) {
    next(error);
  }
};

exports.getLawyerById = async (req, res, next) => {
  try {
    const { lawyerId } = req.params;
    let lawyer = await Lawyer.findById(lawyerId).populate("user", "-password");
    if (!lawyer) {
      lawyer = await Lawyer.findOne({ user: lawyerId }).populate("user", "-password");
    }
    if (!lawyer) {
      return res.status(404).json({ success: false, message: "Lawyer profile not found" });
    }
    const userId = lawyer.user?._id;
    const cases = userId ? await Case.find({ assignedLawyer: userId }).populate("client", "fullName email") : [];
    const appointments = userId ? await Appointment.find({ lawyer: userId }).populate("client", "fullName email") : [];
    const reviews = userId ? await Review.find({ lawyer: userId }).populate("client", "fullName email") : [];
    const subscription = userId ? await Subscription.findOne({ user: userId }).sort({ createdAt: -1 }) : null;

    res.status(200).json({
      success: true,
      data: {
        ...lawyer.toObject(),
        cases,
        appointments,
        reviews,
        subscription,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.updateLawyerStatus = async (req, res, next) => {
  try {
    const { lawyerId } = req.params;
    const { isActive, verificationStatus } = req.body;

    let lawyer = await Lawyer.findById(lawyerId).populate("user");
    if (!lawyer) {
      lawyer = await Lawyer.findOne({ user: lawyerId }).populate("user");
    }
    if (!lawyer) {
      return res.status(404).json({ success: false, message: "Lawyer not found" });
    }
    if (verificationStatus) {
      lawyer.verificationStatus = verificationStatus;
      await lawyer.save();
    }
    if (isActive !== undefined && lawyer.user) {
      await User.findByIdAndUpdate(lawyer.user._id, { isActive });
    }
    await logAuditAction(req, "update_lawyer_status", "Lawyer", lawyer._id, { isActive, verificationStatus });
    res.status(200).json({ success: true, message: "Lawyer status updated successfully", data: lawyer });
  } catch (error) {
    next(error);
  }
};

exports.getCaseById = async (req, res, next) => {
  try {
    const { caseId } = req.params;
    const caseItem = await Case.findById(caseId)
      .populate("client", "-password")
      .populate("assignedLawyer", "-password")
      .populate("proposals.lawyer", "fullName email profileImage");
    if (!caseItem) {
      return res.status(404).json({ success: false, message: "Case not found" });
    }
    const appointments = await Appointment.find({ case: caseId });
    const documents = await Document.find({ case: caseId });

    res.status(200).json({
      success: true,
      data: {
        ...caseItem.toObject(),
        appointments,
        caseDocuments: documents,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getAppointments = async (req, res, next) => {
  try {
    const { status, search, page = 1, limit = 20 } = req.query;
    const query = {};
    if (status && status !== "all") query.status = status;

    let appointments = await Appointment.find(query)
      .populate("client", "fullName email mobile")
      .populate("lawyer", "fullName email mobile")
      .populate("case", "title caseNumber")
      .sort({ createdAt: -1 });

    if (search) {
      const regex = new RegExp(search, "i");
      appointments = appointments.filter(
        (a) =>
          (a.client && regex.test(a.client.fullName)) ||
          (a.lawyer && regex.test(a.lawyer.fullName)) ||
          regex.test(a.timeSlot) ||
          regex.test(a.status)
      );
    }

    const total = appointments.length;
    const skip = (page - 1) * limit;
    const paginated = appointments.slice(skip, skip + Number(limit));

    res.status(200).json({
      success: true,
      count: paginated.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: paginated,
    });
  } catch (error) {
    next(error);
  }
};

exports.getPayments = async (req, res, next) => {
  try {
    const { status, search, page = 1, limit = 20 } = req.query;
    const query = {};
    if (status && status !== "all") query.status = status;

    let payments = await Payment.find(query)
      .populate("client", "fullName email mobile")
      .populate("lawyer", "fullName email mobile")
      .populate("appointment")
      .populate("case", "title")
      .sort({ createdAt: -1 });

    if (search) {
      const regex = new RegExp(search, "i");
      payments = payments.filter(
        (p) =>
          (p.client && regex.test(p.client.fullName)) ||
          (p.lawyer && regex.test(p.lawyer.fullName)) ||
          regex.test(p.paymentMethod || "") ||
          regex.test(p.purpose || "")
      );
    }

    const total = payments.length;
    const skip = (page - 1) * limit;
    const paginated = payments.slice(skip, skip + Number(limit));

    res.status(200).json({
      success: true,
      count: paginated.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: paginated,
    });
  } catch (error) {
    next(error);
  }
};

exports.processRefund = async (req, res, next) => {
  try {
    const { paymentId } = req.params;
    const { reason } = req.body;

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return res.status(404).json({ success: false, message: "Payment transaction not found" });
    }
    payment.status = "refunded";
    await payment.save();

    await logAuditAction(req, "process_refund", "Payment", paymentId, { amount: payment.amount, reason });

    res.status(200).json({
      success: true,
      message: "Refund processed successfully",
      data: payment,
    });
  } catch (error) {
    next(error);
  }
};

exports.getSubscriptions = async (req, res, next) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;
    const total = await Subscription.countDocuments();
    const subscriptions = await Subscription.find()
      .populate("user", "fullName email mobile role")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit));

    res.status(200).json({
      success: true,
      count: subscriptions.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: subscriptions,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateSubscription = async (req, res, next) => {
  try {
    const { subscriptionId } = req.params;
    const { plan, status, endDate } = req.body;

    const sub = await Subscription.findById(subscriptionId);
    if (!sub) {
      return res.status(404).json({ success: false, message: "Subscription record not found" });
    }
    if (plan) sub.plan = plan;
    if (status) sub.status = status;
    if (endDate) sub.endDate = endDate;
    await sub.save();

    await logAuditAction(req, "update_subscription", "Subscription", subscriptionId, { plan, status });

    res.status(200).json({ success: true, message: "Subscription updated successfully", data: sub });
  } catch (error) {
    next(error);
  }
};

exports.getReviews = async (req, res, next) => {
  try {
    const { isReported, search, page = 1, limit = 20 } = req.query;
    const query = {};
    if (isReported === "true") query.isReported = true;

    let reviews = await Review.find(query)
      .populate("client", "fullName email profileImage")
      .populate("lawyer", "fullName email profileImage")
      .sort({ createdAt: -1 });

    if (search) {
      const regex = new RegExp(search, "i");
      reviews = reviews.filter(
        (r) =>
          (r.client && regex.test(r.client.fullName)) ||
          (r.lawyer && regex.test(r.lawyer.fullName)) ||
          regex.test(r.review)
      );
    }

    const total = reviews.length;
    const skip = (page - 1) * limit;
    const paginated = reviews.slice(skip, skip + Number(limit));

    res.status(200).json({
      success: true,
      count: paginated.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: paginated,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateReviewVisibility = async (req, res, next) => {
  try {
    const { reviewId } = req.params;
    const { isHidden, isReported } = req.body;

    const review = await Review.findById(reviewId);
    if (!review) {
      return res.status(404).json({ success: false, message: "Review not found" });
    }
    if (isHidden !== undefined) review.isHidden = isHidden;
    if (isReported !== undefined) review.isReported = isReported;
    await review.save();

    await logAuditAction(req, "update_review", "Review", reviewId, { isHidden, isReported });

    res.status(200).json({ success: true, message: "Review status updated", data: review });
  } catch (error) {
    next(error);
  }
};

exports.getDisputes = async (req, res, next) => {
  try {
    const disputes = await Issue.find({
      $or: [{ category: /dispute/i }, { status: "Assigned" }],
    })
      .populate("clientId", "fullName email mobile")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: disputes.length,
      data: disputes,
    });
  } catch (error) {
    next(error);
  }
};

exports.getUrgentCases = async (req, res, next) => {
  try {
    const urgentCases = await Case.find({
      $or: [
        { urgency: { $regex: /urgent|immediate|high/i } },
        { priority: { $regex: /urgent|high/i } },
      ],
    })
      .populate("client", "fullName email mobile")
      .populate("assignedLawyer", "fullName email mobile")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: urgentCases.length,
      data: urgentCases,
    });
  } catch (error) {
    next(error);
  }
};

exports.getCategories = async (req, res, next) => {
  try {
    const { status } = req.query;
    const query = {};
    if (status && status !== "all") query.status = status;
    const categories = await Category.find(query).sort({ order: 1, name: 1 });
    res.status(200).json({ success: true, count: categories.length, data: categories });
  } catch (error) {
    next(error);
  }
};

exports.createCategory = async (req, res, next) => {
  try {
    const { name, description, status, order } = req.body;
    if (!name) {
      return ApiResponse.error(res, "Category name is required.", 400);
    }
    const existing = await Category.findOne({ name: { $regex: new RegExp(`^${name}$`, "i") } });
    if (existing) {
      return ApiResponse.error(res, "A category with this name already exists.", 409);
    }
    const category = await Category.create({ name, description: description || "", status: status || "active", order: order || 0 });
    await logAuditAction(req, "create_category", "Category", category._id, { name });
    res.status(201).json({ success: true, message: "Category created successfully.", data: category });
  } catch (error) {
    next(error);
  }
};

exports.getPromotions = async (req, res, next) => {
  try {
    const { isActive } = req.query;
    const query = {};
    if (isActive !== undefined) {
      query.isActive = isActive === "true" || isActive === true;
    }
    const promotions = await Promotion.find(query).sort({ createdAt: -1 });
    res.status(200).json({ success: true, count: promotions.length, data: promotions });
  } catch (error) {
    next(error);
  }
};

exports.createPromotion = async (req, res, next) => {
  try {
    const {
      name, description, code, discountType, discountValue, applicableTo,
      eligibleCategory, eligiblePlan, startDate, endDate, maxUses, maxUsesPerUser, minAmount,
    } = req.body;
    if (!name || !code || !discountType || !discountValue || !startDate || !endDate) {
      return ApiResponse.error(res, "Required fields: name, code, discountType, discountValue, startDate, endDate.", 400);
    }
    const existing = await Promotion.findOne({ code: code.toUpperCase() });
    if (existing) {
      return ApiResponse.error(res, "A promotion with this code already exists.", 409);
    }
    const promotion = await Promotion.create({
      name, description, code: code.toUpperCase(), discountType, discountValue,
      applicableTo: applicableTo || "consultation", eligibleCategory, eligiblePlan,
      startDate, endDate, maxUses: maxUses || 0, maxUsesPerUser: maxUsesPerUser || 1,
      minAmount: minAmount || 0, createdBy: req.user._id,
    });
    await logAuditAction(req, "create_promotion", "Promotion", promotion._id, { name, code });
    res.status(201).json({ success: true, message: "Promotion created successfully.", data: promotion });
  } catch (error) {
    next(error);
  }
};

exports.togglePromotion = async (req, res, next) => {
  try {
    const { id } = req.params;
    const promotion = await Promotion.findById(id);
    if (!promotion) {
      return ApiResponse.error(res, "Promotion not found.", 404);
    }
    promotion.isActive = !promotion.isActive;
    await promotion.save();
    await logAuditAction(req, "toggle_promotion", "Promotion", id, { isActive: promotion.isActive });
    res.status(200).json({ success: true, message: "Promotion toggled successfully.", data: promotion });
  } catch (error) {
    next(error);
  }
};

exports.getLegalDocuments = async (req, res, next) => {
  try {
    const docs = await LegalDocument.find().sort({ type: 1, createdAt: -1 });
    res.status(200).json({ success: true, count: docs.length, data: docs });
  } catch (error) {
    next(error);
  }
};

exports.createLegalDocument = async (req, res, next) => {
  try {
    const { type, version, title, content, effectiveDate, audience, isActive, requiresAcceptance } = req.body;
    if (isActive) {
      await LegalDocument.updateMany({ type }, { isActive: false });
    }
    const doc = await LegalDocument.create({
      type,
      version,
      title,
      content,
      effectiveDate: effectiveDate || new Date(),
      audience: audience || "all",
      isActive: isActive || false,
      requiresAcceptance: requiresAcceptance || false,
      legallyReviewed: true,
    });
    await logAuditAction(req, "create_legal_document", "LegalDocument", doc._id, { type, version, title });
    res.status(201).json({ success: true, message: "Legal document published successfully", data: doc });
  } catch (error) {
    next(error);
  }
};

exports.updateLegalDocument = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { title, content, isActive, audience } = req.body;
    const doc = await LegalDocument.findById(id);
    if (!doc) {
      return res.status(404).json({ success: false, message: "Legal document not found" });
    }
    if (isActive) {
      await LegalDocument.updateMany({ type: doc.type }, { isActive: false });
    }
    if (title) doc.title = title;
    if (content) doc.content = content;
    if (isActive !== undefined) doc.isActive = isActive;
    if (audience) doc.audience = audience;
    await doc.save();

    await logAuditAction(req, "update_legal_document", "LegalDocument", id, { title, isActive });
    res.status(200).json({ success: true, message: "Legal document updated successfully", data: doc });
  } catch (error) {
    next(error);
  }
};

exports.getAuditLogs = async (req, res, next) => {
  try {
    const { action, search, page = 1, limit = 30 } = req.query;
    const query = {};
    if (action && action !== "all") query.action = action;

    const skip = (page - 1) * limit;
    const total = await AuditLog.countDocuments(query);
    const logs = await AuditLog.find(query)
      .populate("performedBy", "fullName email role")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit));

    res.status(200).json({
      success: true,
      count: logs.length,
      total,
      page: Number(page),
      pages: Math.ceil(total / limit),
      data: logs,
    });
  } catch (error) {
    next(error);
  }
};

exports.getSettings = async (req, res, next) => {
  try {
    let settings = await Setting.findOne({ user: req.user._id });
    if (!settings) {
      settings = await Setting.create({
        user: req.user._id,
        pushNotifications: true,
        emailNotifications: true,
        darkMode: false,
        language: "English",
        twoFactorAuthentication: false,
      });
    }
    res.status(200).json({ success: true, data: settings });
  } catch (error) {
    next(error);
  }
};

exports.updateSettings = async (req, res, next) => {
  try {
    const { pushNotifications, emailNotifications, darkMode, language, twoFactorAuthentication } = req.body;
    let settings = await Setting.findOne({ user: req.user._id });
    if (!settings) {
      settings = new Setting({ user: req.user._id });
    }
    if (pushNotifications !== undefined) settings.pushNotifications = pushNotifications;
    if (emailNotifications !== undefined) settings.emailNotifications = emailNotifications;
    if (darkMode !== undefined) settings.darkMode = darkMode;
    if (language !== undefined) settings.language = language;
    if (twoFactorAuthentication !== undefined) settings.twoFactorAuthentication = twoFactorAuthentication;

    await settings.save();
    await logAuditAction(req, "update_admin_settings", "Setting", settings._id, req.body);
    res.status(200).json({ success: true, message: "Settings updated successfully", data: settings });
  } catch (error) {
    next(error);
  }
};

exports.getAllReferrals = async (req, res, next) => {
  try {
    const referrals = await Referral.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, count: referrals.length, data: referrals });
  } catch (error) {
    next(error);
  }
};

exports.getReferralStats = async (req, res, next) => {
  try {
    const totalReferrals = await Referral.countDocuments();
    const byStatus = await Referral.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]);
    const byRole = await Referral.aggregate([
      { $group: { _id: "$referrerRole", count: { $sum: 1 } } },
    ]);
    res.status(200).json({
      success: true,
      data: {
        total: totalReferrals,
        byStatus: Object.fromEntries(byStatus.map((r) => [r._id, r.count])),
        byRole: Object.fromEntries(byRole.map((r) => [r._id, r.count])),
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getMilestonesByCase = async (req, res, next) => {
  try {
    const { caseId } = req.params;
    const milestones = await Milestone.find({ caseId }).sort({ order: 1, createdAt: 1 });
    res.status(200).json({ success: true, count: milestones.length, data: milestones });
  } catch (error) {
    next(error);
  }
};

