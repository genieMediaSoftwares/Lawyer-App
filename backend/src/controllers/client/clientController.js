const User = require("../../models/User");
const Client = require("../../models/Client");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const Document = require("../../models/Document");
const Payment = require("../../models/Payment");
const ApiResponse = require("../../config/ApiResponse");

class ClientController {
  async getClients(req, res, next) {
    try {
      const lawyerId = req.user._id;

      // Find all unique client user IDs from appointments or assigned cases
      const appointments = await Appointment.find({ lawyer: lawyerId }).distinct("client");
      const cases = await Case.find({ assignedLawyer: lawyerId }).distinct("client");

      const uniqueClientIds = [...new Set([...appointments, ...cases])];

      const clients = await User.find({ _id: { $in: uniqueClientIds } })
        .select("fullName email mobile profileImage location")
        .sort({ fullName: 1 });

      return ApiResponse.success(res, "Clients fetched successfully.", clients);
    } catch (error) {
      next(error);
    }
  }

  async getClientById(req, res, next) {
    try {
      const { id } = req.params;
      const lawyerId = req.user._id;

      const clientUser = await User.findById(id).select("fullName email mobile profileImage location");
      if (!clientUser) {
        return ApiResponse.error(res, "Client not found.", 404);
      }

      // Fetch client metadata details
      let clientProfile = await Client.findOne({ user: id });
      if (!clientProfile) {
        clientProfile = await Client.create({ user: id });
      }

      // Fetch Case history
      const caseHistory = await Case.find({ client: id, assignedLawyer: lawyerId });

      // Fetch Documents
      const documents = await Document.find({ clientId: id });

      // Fetch Appointments
      const appointments = await Appointment.find({ client: id, lawyer: lawyerId });

      return ApiResponse.success(res, "Client profile retrieved.", {
        client: clientUser,
        profile: clientProfile,
        caseHistory,
        documents,
        appointments,
      });
    } catch (error) {
      next(error);
    }
  }

  async addNote(req, res, next) {
    try {
      const { id } = req.params;
      const { text } = req.body;
      const lawyerId = req.user._id;

      if (!text) {
        return ApiResponse.error(res, "Note content is required.", 400);
      }

      let clientProfile = await Client.findOne({ user: id });
      if (!clientProfile) {
        clientProfile = await Client.create({ user: id });
      }

      clientProfile.notes.push({
        lawyer: lawyerId,
        text,
        date: new Date(),
      });

      await clientProfile.save();

      return ApiResponse.success(res, "Note added to client profile successfully.", clientProfile);
    } catch (error) {
      next(error);
    }
  }

  async getNotes(req, res, next) {
    try {
      const { id } = req.params;
      const lawyerId = req.user._id;

      const clientProfile = await Client.findOne({ user: id }).populate("notes.lawyer", "fullName profileImage");
      if (!clientProfile) {
        return ApiResponse.success(res, "No client notes found.", []);
      }

      // Filter notes authored by this lawyer
      const lawyerNotes = clientProfile.notes.filter(
        (n) => n.lawyer._id.toString() === lawyerId.toString()
      );

      return ApiResponse.success(res, "Client notes fetched.", lawyerNotes);
    } catch (error) {
      next(error);
    }
  }

  async getClientProfile(req, res, next) {
    try {
      const user = await User.findById(req.user._id).select("-password");
      if (!user) {
        return ApiResponse.error(res, "User not found.", 404);
      }
      let clientProfile = await Client.findOne({ user: req.user._id });
      if (!clientProfile) {
        clientProfile = await Client.create({ user: req.user._id });
      }
      return ApiResponse.success(res, "Client profile retrieved successfully.", {
        user,
        profile: clientProfile
      });
    } catch (error) {
      next(error);
    }
  }

  async updateClientProfile(req, res, next) {
    try {
      const { fullName, mobile, location, dob, gender, languages } = req.body;
      const updateData = {};
      if (fullName !== undefined) updateData.fullName = fullName;
      if (mobile !== undefined) updateData.mobile = mobile;
      if (location !== undefined) updateData.location = location;
      if (dob !== undefined) updateData.dob = dob;
      if (gender !== undefined) updateData.gender = gender;
      if (languages !== undefined) updateData.languages = languages;

      const user = await User.findByIdAndUpdate(
        req.user._id,
        { $set: updateData },
        { new: true }
      ).select("-password");

      if (!user) {
        return ApiResponse.error(res, "User not found.", 404);
      }

      let clientProfile = await Client.findOne({ user: req.user._id });
      if (!clientProfile) {
        clientProfile = await Client.create({ user: req.user._id });
      }
      if (location !== undefined) clientProfile.address = location;
      if (languages !== undefined) clientProfile.preferredLanguages = languages;
      await clientProfile.save();

      return ApiResponse.success(res, "Client profile updated successfully.", {
        user,
        profile: clientProfile
      });
    } catch (error) {
      next(error);
    }
  }

  async getClientActivity(req, res, next) {
    try {
      const userId = req.user._id;
      const activities = [];

      // 1. Profile updated activity (default fallback)
      activities.push({
        title: "Profile updated",
        description: "Personal details updated",
        date: req.user.updatedAt || req.user.createdAt || new Date(),
        type: "profile"
      });

      // 2. Documents uploaded
      const documents = await Document.find({ clientId: userId }).sort({ createdAt: -1 }).limit(5);
      documents.forEach(doc => {
        activities.push({
          title: "Document uploaded",
          description: `${doc.originalName} uploaded`,
          date: doc.uploadedAt || doc.createdAt,
          type: "document"
        });
      });

      // 3. Appointments booked
      const appointments = await Appointment.find({ client: userId }).populate("lawyer", "fullName").sort({ createdAt: -1 }).limit(5);
      appointments.forEach(app => {
        activities.push({
          title: "Consultation booked",
          description: `Consultation with ${app.lawyer?.fullName || "Advocate"} booked`,
          date: app.createdAt,
          type: "consultation"
        });
      });

      // 4. Payments completed
      const payments = await Payment.find({ client: userId }).populate("lawyer", "fullName").sort({ createdAt: -1 }).limit(5);
      payments.forEach(pay => {
        activities.push({
          title: "Payment successful",
          description: `Payment of ₹${pay.amount} completed`,
          date: pay.createdAt,
          type: "payment"
        });
      });

      // Sort all by date desc
      activities.sort((a, b) => new Date(b.date) - new Date(a.date));

      return ApiResponse.success(res, "Client activity fetched successfully.", activities);
    } catch (error) {
      next(error);
    }
  }

  async getClientStats(req, res, next) {
    try {
      const userId = req.user._id;
      const activeCases = await Case.countDocuments({ client: userId, status: "In Progress" });
      const totalCases = await Case.countDocuments({ client: userId });
      const totalAppointments = await Appointment.countDocuments({ client: userId });
      const totalDocuments = await Document.countDocuments({ clientId: userId });

      return ApiResponse.success(res, "Client stats retrieved successfully.", {
        activeCases,
        totalCases,
        totalAppointments,
        totalDocuments
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ClientController();
