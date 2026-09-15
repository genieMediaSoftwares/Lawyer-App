const User = require("../../models/User");
const Client = require("../../models/Client");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const Document = require("../../models/Document");
const Payment = require("../../models/Payment");
const ApiResponse = require("../../config/ApiResponse");

/**
 * True if `lawyerId` actually acts for the client user `clientUserId`.
 *
 * This is the same relationship getClients already uses to build an advocate's
 * client list - a case they are assigned to, or a consultation booked with
 * them - so the detail, notes and activity endpoints below admit exactly the
 * clients that appear in that list, and no others.
 *
 * It is applied because these endpoints previously took a client id from the
 * URL and answered without checking anything: any authenticated user could
 * read any client's profile, contact details and full document list, and write
 * notes onto any client's record, by changing the id.
 */
const isEngagedWithClient = async (lawyerId, clientUserId) => {
  const [byCase, byAppointment] = await Promise.all([
    Case.exists({ client: clientUserId, assignedLawyer: lawyerId }),
    Appointment.exists({ client: clientUserId, lawyer: lawyerId }),
  ]);
  return Boolean(byCase || byAppointment);
};

/**
 * Resolves the client record an advocate is asking about, or the reason they
 * may not have it.
 *
 * Returns `{ error, status }` for the caller to hand straight to ApiResponse,
 * so the four endpoints below cannot drift apart on who is allowed in.
 */
const resolveClientForLawyer = async (user, clientUserId) => {
  if (user.role !== "lawyer" && user.role !== "admin") {
    return { error: "Access forbidden.", status: 403 };
  }

  const clientUser = await User.findById(clientUserId).select(
    "fullName email mobile profileImage location"
  );
  if (!clientUser) {
    return { error: "Client not found.", status: 404 };
  }

  if (
    user.role === "lawyer" &&
    !(await isEngagedWithClient(user._id, clientUserId))
  ) {
    // 404 rather than 403: a 403 would confirm that this user exists and is a
    // client of some other advocate.
    return { error: "Client not found.", status: 404 };
  }

  return { clientUser };
};

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

      const { clientUser, error, status } = await resolveClientForLawyer(
        req.user,
        id
      );
      if (error) {
        return ApiResponse.error(res, error, status);
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

      // The notes array is dropped from the profile before it is returned: it
      // holds every advocate's private notes on this client, and getNotes below
      // is the only endpoint that reads it - filtered to its author.
      const profile = clientProfile.toObject();
      delete profile.notes;

      return ApiResponse.success(res, "Client profile retrieved.", {
        client: clientUser,
        profile,
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
      const { text, title, caseId } = req.body;
      const lawyerId = req.user._id;

      if (!text || !text.trim()) {
        return ApiResponse.error(res, "Note content is required.", 400);
      }

      const { error, status } = await resolveClientForLawyer(req.user, id);
      if (error) {
        return ApiResponse.error(res, error, status);
      }

      // A note may be filed against a case, but only one this advocate is
      // actually on and that belongs to this client - otherwise the caseId
      // would be a way to attach a note to someone else's matter.
      if (caseId) {
        const ownsCase = await Case.exists({
          _id: caseId,
          client: id,
          $or: [{ assignedLawyer: lawyerId }, { selectedLawyer: lawyerId }],
        });
        if (!ownsCase) {
          return ApiResponse.error(res, "Case not found.", 404);
        }
      }

      let clientProfile = await Client.findOne({ user: id });
      if (!clientProfile) {
        clientProfile = await Client.create({ user: id });
      }

      clientProfile.notes.push({
        lawyer: lawyerId,
        text: text.trim(),
        title: (title || "").trim(),
        case: caseId || null,
        date: new Date(),
        updatedAt: new Date(),
      });

      await clientProfile.save();

      // Only the note just written is returned. Returning the whole profile
      // handed the caller every other advocate's private notes on this client.
      const created = clientProfile.notes[clientProfile.notes.length - 1];

      return ApiResponse.success(
        res,
        "Note added to client profile successfully.",
        created,
        201
      );
    } catch (error) {
      next(error);
    }
  }

  async getNotes(req, res, next) {
    try {
      const { id } = req.params;
      const { caseId } = req.query;
      const lawyerId = req.user._id;

      const { error, status } = await resolveClientForLawyer(req.user, id);
      if (error) {
        return ApiResponse.error(res, error, status);
      }

      const clientProfile = await Client.findOne({ user: id }).populate("notes.lawyer", "fullName profileImage");
      if (!clientProfile) {
        return ApiResponse.success(res, "No client notes found.", []);
      }

      // Filter notes authored by this lawyer. The `n.lawyer &&` guard matters:
      // a note whose author reference is missing used to throw here and take
      // the whole request down with it.
      let lawyerNotes = clientProfile.notes.filter(
        (n) =>
          n.lawyer &&
          (n.lawyer._id || n.lawyer).toString() === lawyerId.toString()
      );

      if (caseId) {
        lawyerNotes = lawyerNotes.filter(
          (n) => n.case && n.case.toString() === caseId.toString()
        );
      }

      // Newest first, so the list opens on what the advocate wrote last.
      lawyerNotes = lawyerNotes.sort(
        (a, b) => new Date(b.date) - new Date(a.date)
      );

      return ApiResponse.success(res, "Client notes fetched.", lawyerNotes);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Edits a note. Author-only: an advocate may not touch a note another
   * advocate wrote about the same client, and the client themselves has no
   * endpoint that reaches this array at all.
   */
  async updateNote(req, res, next) {
    try {
      const { id, noteId } = req.params;
      const { text, title, caseId } = req.body;
      const lawyerId = req.user._id;

      const { error, status } = await resolveClientForLawyer(req.user, id);
      if (error) {
        return ApiResponse.error(res, error, status);
      }

      const clientProfile = await Client.findOne({ user: id });
      if (!clientProfile) {
        return ApiResponse.error(res, "Note not found.", 404);
      }

      const note = clientProfile.notes.id(noteId);
      if (
        !note ||
        !note.lawyer ||
        note.lawyer.toString() !== lawyerId.toString()
      ) {
        return ApiResponse.error(res, "Note not found.", 404);
      }

      if (text !== undefined) {
        if (!text.trim()) {
          return ApiResponse.error(res, "Note content is required.", 400);
        }
        note.text = text.trim();
      }
      if (title !== undefined) note.title = title.trim();

      if (caseId !== undefined) {
        if (caseId) {
          const ownsCase = await Case.exists({
            _id: caseId,
            client: id,
            $or: [{ assignedLawyer: lawyerId }, { selectedLawyer: lawyerId }],
          });
          if (!ownsCase) {
            return ApiResponse.error(res, "Case not found.", 404);
          }
        }
        note.case = caseId || null;
      }

      note.updatedAt = new Date();
      await clientProfile.save();

      return ApiResponse.success(res, "Note updated successfully.", note);
    } catch (error) {
      next(error);
    }
  }

  async deleteNote(req, res, next) {
    try {
      const { id, noteId } = req.params;
      const lawyerId = req.user._id;

      const { error, status } = await resolveClientForLawyer(req.user, id);
      if (error) {
        return ApiResponse.error(res, error, status);
      }

      const clientProfile = await Client.findOne({ user: id });
      if (!clientProfile) {
        return ApiResponse.error(res, "Note not found.", 404);
      }

      const note = clientProfile.notes.id(noteId);
      if (
        !note ||
        !note.lawyer ||
        note.lawyer.toString() !== lawyerId.toString()
      ) {
        return ApiResponse.error(res, "Note not found.", 404);
      }

      note.deleteOne();
      await clientProfile.save();

      return ApiResponse.success(res, "Note deleted successfully.", null);
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
