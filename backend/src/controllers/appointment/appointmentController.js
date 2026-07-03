const Appointment = require("../../models/Appointment");
const Case = require("../../models/Case");
const ApiResponse = require("../../config/ApiResponse");

class AppointmentController {
  async createAppointment(req, res, next) {
    try {
      const { lawyer, caseId, date, timeSlot, mode } = req.body;
      const client = req.user._id;

      const appointment = await Appointment.create({
        client,
        lawyer,
        case: caseId || null,
        date,
        timeSlot,
        mode,
        status: "confirmed" // Automatically confirm for this demo/flow
      });

      // If linked to a case, update the "Consultation Scheduled" milestone to true
      if (caseId) {
        const caseItem = await Case.findById(caseId);
        if (caseItem) {
          const milestone = caseItem.milestones.find((m) => m.title === "Consultation Scheduled");
          if (milestone) {
            milestone.isCompleted = true;
          }
          await caseItem.save();
        }
      }

      return ApiResponse.success(res, "Appointment booked successfully.", appointment, 201);
    } catch (error) {
      next(error);
    }
  }

  async getAppointments(req, res, next) {
    try {
      let query = {};
      if (req.user.role === "client") {
        query.client = req.user._id;
      } else if (req.user.role === "lawyer") {
        query.lawyer = req.user._id;
      }

      const appointments = await Appointment.find(query)
        .populate("client", "fullName email mobile profileImage")
        .populate("lawyer", "fullName email mobile profileImage")
        .populate("case", "title category")
        .sort({ date: 1, timeSlot: 1 });

      return ApiResponse.success(res, "Appointments fetched successfully.", appointments);
    } catch (error) {
      next(error);
    }
  }

  async updateStatus(req, res, next) {
    try {
      const { id } = req.params;
      const { status } = req.body;

      const appointment = await Appointment.findById(id);
      if (!appointment) {
        return ApiResponse.error(res, "Appointment not found.", 404);
      }

      appointment.status = status;
      await appointment.save();

      return ApiResponse.success(res, `Appointment status updated to ${status}.`, appointment);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AppointmentController();
