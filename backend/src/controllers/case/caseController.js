const Case = require("../../models/Case");
const User = require("../../models/User");
const ApiResponse = require("../../config/ApiResponse");

class CaseController {
  async createCase(req, res, next) {
    try {
      const { title, description, category, location, budgetRange, urgency, preferredCourt, documents } = req.body;
      const client = req.user._id;

      // Add default milestones for case tracking
      const milestones = [
        { title: "Case Posted", isCompleted: true },
        { title: "Proposals Received", isCompleted: false },
        { title: "Consultation Scheduled", isCompleted: false },
        { title: "In Progress", isCompleted: false },
        { title: "Closed", isCompleted: false }
      ];

      const newCase = await Case.create({
        client,
        title,
        description,
        category,
        location,
        budgetRange: budgetRange || "",
        urgency,
        preferredCourt: preferredCourt || "",
        documents: documents || [],
        milestones
      });

      return ApiResponse.success(res, "Case created successfully.", newCase, 201);
    } catch (error) {
      next(error);
    }
  }

  async getCases(req, res, next) {
    try {
      let query = {};
      if (req.user.role === "client") {
        query.client = req.user._id;
      } else if (req.user.role === "lawyer") {
        // Lawyers see submitted cases or cases they are assigned to
        query = {
          $or: [
            { status: "Submitted" },
            { assignedLawyer: req.user._id }
          ]
        };
      }

      const cases = await Case.find(query)
        .populate("client", "fullName email mobile profileImage")
        .populate("assignedLawyer", "fullName email mobile profileImage")
        .populate("proposals.lawyer", "fullName email mobile profileImage")
        .sort({ createdAt: -1 });

      return ApiResponse.success(res, "Cases fetched successfully.", cases);
    } catch (error) {
      next(error);
    }
  }

  async getCaseById(req, res, next) {
    try {
      const { id } = req.params;
      const caseItem = await Case.findById(id)
        .populate("client", "fullName email mobile profileImage")
        .populate("assignedLawyer", "fullName email mobile profileImage")
        .populate("proposals.lawyer", "fullName email mobile profileImage");

      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      return ApiResponse.success(res, "Case details fetched successfully.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async submitProposal(req, res, next) {
    try {
      const { id } = req.params;
      const { feeProposal, message } = req.body;
      const lawyerId = req.user._id;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      // Check if lawyer already responded
      const existingProposalIndex = caseItem.proposals.findIndex(
        (p) => p.lawyer.toString() === lawyerId.toString()
      );

      if (existingProposalIndex > -1) {
        caseItem.proposals[existingProposalIndex].feeProposal = feeProposal;
        caseItem.proposals[existingProposalIndex].message = message;
      } else {
        caseItem.proposals.push({
          lawyer: lawyerId,
          feeProposal,
          message
        });
      }

      // Set Proposals Received milestone to true
      const proposalsMilestone = caseItem.milestones.find((m) => m.title === "Proposals Received");
      if (proposalsMilestone) {
        proposalsMilestone.isCompleted = true;
      }

      await caseItem.save();

      const updatedCase = await Case.findById(id)
        .populate("proposals.lawyer", "fullName email mobile profileImage");

      return ApiResponse.success(res, "Proposal submitted successfully.", updatedCase);
    } catch (error) {
      next(error);
    }
  }

  async acceptProposal(req, res, next) {
    try {
      const { id } = req.params;
      const { lawyerId } = req.body;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      caseItem.assignedLawyer = lawyerId;
      caseItem.status = "In Progress";

      // Mark In Progress milestone to true
      const inProgressMilestone = caseItem.milestones.find((m) => m.title === "In Progress");
      if (inProgressMilestone) {
        inProgressMilestone.isCompleted = true;
      }

      await caseItem.save();

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        if (caseItem.assignedLawyer) {
          io.of("/cases").to(caseItem.assignedLawyer.toString()).emit("case_updated", caseItem);
        }
      }

      return ApiResponse.success(res, "Proposal accepted and lawyer assigned.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async updateMilestone(req, res, next) {
    try {
      const { id } = req.params;
      const { milestoneTitle, isCompleted } = req.body;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      const milestone = caseItem.milestones.find((m) => m.title === milestoneTitle);
      if (!milestone) {
        return ApiResponse.error(res, "Milestone not found.", 404);
      }

      milestone.isCompleted = isCompleted;

      // If Closed milestone is completed, set case status to closed
      if (milestoneTitle === "Closed" && isCompleted) {
        caseItem.status = "Closed";
      }

      await caseItem.save();

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        if (caseItem.assignedLawyer) {
          io.of("/cases").to(caseItem.assignedLawyer.toString()).emit("case_updated", caseItem);
        }
      }

      return ApiResponse.success(res, "Milestone updated successfully.", caseItem);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CaseController();
