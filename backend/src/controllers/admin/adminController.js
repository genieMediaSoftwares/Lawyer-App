const User = require("../../models/User");
const Lawyer = require("../../models/Lawyer");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const Document = require("../../models/Document");
const Issue = require("../../models/Issue");
const AiConversation = require("../../models/AiConversation");
const Notification = require("../../models/Notification");
const Chat = require("../../models/Chat");

// 1. Dashboard Statistics
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

// 2. Client Management
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

// 3. Lawyer Management
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

// 4. Lawyer Verification Action
exports.verifyLawyer = async (req, res, next) => {
  try {
    const { lawyerId } = req.params;
    const { status, rejectionReason, isActive } = req.body;

    const lawyer = await Lawyer.findById(lawyerId).populate("user");
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

    const io = req.app.get("io");
    if (io) {
      io.emit("lawyer_verification_updated", { lawyerId, status: lawyer.verificationStatus });
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

// 5. Case Management
exports.getCases = async (req, res, next) => {
  try {
    const { status, search, page = 1, limit = 20 } = req.query;
    const query = {};

    if (status && status !== "all") {
      query.status = { $regex: new RegExp(status, "i") };
    }

    let cases = await Case.find(query)
      .populate("client", "-password")
      .populate({
        path: "assignedLawyer",
        populate: { path: "user", select: "-password" },
      })
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

// 6. Update Case Status
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

// 7. Documents Vault Overview
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

// 8. AI Analytics
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

// 9. Support Tickets Management
exports.getSupportTickets = async (req, res, next) => {
  try {
    const { status, search } = req.query;
    const query = {};

    if (status && status !== "all") query.status = status;
    if (search) {
      // Against the Issue schema's real fields. This searched `subject` and
      // `ticketId`, neither of which exists on Issue, so two thirds of the
      // filter silently matched nothing.
      query.$or = [
        { title: { $regex: search, $options: "i" } },
        { description: { $regex: search, $options: "i" } },
        { category: { $regex: search, $options: "i" } },
      ];
    }

    // The raiser is stored as `clientId`; populating "user" produced null on
    // every ticket, so the admin queue showed no requester at all.
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

// 10. Broadcast Push Notification
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

// 11. System Analytics Data
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

// 12. Dynamic Reports Export Data
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
