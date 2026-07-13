const Appointment = require("../../models/Appointment");
const Case = require("../../models/Case");
const ApiResponse = require("../../config/ApiResponse");
const notificationService = require("../../services/notification/notificationService");

class AppointmentController {
  async createAppointment(req, res, next) {
    try {
      const { lawyer, client: bodyClient, caseId, date, timeSlot, mode } = req.body;
      
      let client = req.user._id;
      let lawyerId = lawyer;

      if (req.user.role === "lawyer") {
        client = bodyClient;
        lawyerId = req.user._id;
      }

      const appointment = await Appointment.create({
        client,
        lawyer: lawyerId,
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

      // Notify both parties
      await notificationService.createAndSendNotification({
        senderId: req.user._id,
        receiverId: client,
        type: "appointment_requested",
        title: "Appointment Booked",
        message: `Your appointment has been scheduled for ${date} at ${timeSlot}.`,
        referenceId: appointment._id.toString()
      });

      await notificationService.createAndSendNotification({
        senderId: req.user._id,
        receiverId: lawyerId,
        type: "appointment_requested",
        title: "New Appointment Scheduled",
        message: `An appointment has been scheduled for ${date} at ${timeSlot}.`,
        referenceId: appointment._id.toString()
      });

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

      // Trigger status update notifications
      const notifyUser = req.user.role === "client" ? appointment.lawyer : appointment.client;
      await notificationService.createAndSendNotification({
        senderId: req.user._id,
        receiverId: notifyUser,
        type: status === "confirmed" ? "appointment_confirmed" : (status === "cancelled" ? "appointment_cancelled" : "general"),
        title: `Appointment ${status.charAt(0).toUpperCase() + status.slice(1)}`,
        message: `Your appointment on ${appointment.date} has been ${status}.`,
        referenceId: appointment._id.toString()
      });

      return ApiResponse.success(res, `Appointment status updated to ${status}.`, appointment);
    } catch (error) {
      next(error);
    }
  }

  async updateAppointment(req, res, next) {
    try {
      const { id } = req.params;
      const updates = req.body;

      const appointment = await Appointment.findByIdAndUpdate(id, updates, { new: true, runValidators: true });
      if (!appointment) {
        return ApiResponse.error(res, "Appointment not found.", 404);
      }

      return ApiResponse.success(res, "Appointment updated successfully.", appointment);
    } catch (error) {
      next(error);
    }
  }

  async deleteAppointment(req, res, next) {
    try {
      const { id } = req.params;
      const appointment = await Appointment.findById(id);
      if (!appointment) {
        return ApiResponse.error(res, "Appointment not found.", 404);
      }
      
      appointment.status = "cancelled";
      await appointment.save();

      // Trigger cancelled notifications
      const notifyUser = req.user._id.toString() === appointment.client.toString() ? appointment.lawyer : appointment.client;
      await notificationService.createAndSendNotification({
        senderId: req.user._id,
        receiverId: notifyUser,
        type: "appointment_cancelled",
        title: "Appointment Cancelled",
        message: `Your appointment scheduled on ${appointment.date} has been cancelled.`,
        referenceId: appointment._id.toString()
      });

      return ApiResponse.success(res, "Appointment cancelled successfully.", appointment);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AppointmentController();
