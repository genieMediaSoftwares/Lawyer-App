const User = require("../../models/User");
const Client = require("../../models/Client");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const Document = require("../../models/Document");
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
}

module.exports = new ClientController();
