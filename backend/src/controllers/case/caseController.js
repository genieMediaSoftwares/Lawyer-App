const Case = require("../../models/Case");
const User = require("../../models/User");
const Lawyer = require("../../models/Lawyer");
const ApiResponse = require("../../config/ApiResponse");

class CaseController {
  async createCase(req, res, next) {
    try {
      const { title, description, category, subcategory, location, budgetRange, urgency, preferredCourt, documents, selectedLawyer } = req.body;
      const client = req.user._id;

      const hasSelectedLawyer = !!selectedLawyer;
      const milestones = hasSelectedLawyer
        ? [
            { title: "Case Posted", isCompleted: true },
            { title: "Awaiting Lawyer Acceptance", isCompleted: true },
            { title: "In Progress", isCompleted: false },
            { title: "Closed", isCompleted: false }
          ]
        : [
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
        subcategory: subcategory || "",
        location,
        budgetRange: budgetRange || "",
        urgency,
        preferredCourt: preferredCourt || "",
        documents: documents || [],
        selectedLawyer: selectedLawyer || null,
        status: hasSelectedLawyer ? "Awaiting Lawyer Acceptance" : "Submitted",
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
        // Lawyers see:
        // 1. Submitted cases
        // 2. Cases they are assigned to
        // 3. Cases where they are the selectedLawyer (direct requests)
        query = {
          $or: [
            { status: "Submitted" },
            { assignedLawyer: req.user._id },
            { selectedLawyer: req.user._id }
          ]
        };
      }

      const cases = await Case.find(query)
        .populate("client", "fullName email mobile profileImage")
        .populate("assignedLawyer", "fullName email mobile profileImage")
        .populate("selectedLawyer", "fullName email mobile profileImage isVerified")
        .populate("proposals.lawyer", "fullName email mobile profileImage")
        .sort({ createdAt: -1 })
        .lean();

      // Retrieve lawyer profile details dynamically
      for (let c of cases) {
        if (c.selectedLawyer) {
          const profile = await Lawyer.findOne({ user: c.selectedLawyer._id }).lean();
          if (profile) {
            c.selectedLawyerProfile = profile;
          }
        }
        if (c.assignedLawyer) {
          const profile = await Lawyer.findOne({ user: c.assignedLawyer._id }).lean();
          if (profile) {
            c.assignedLawyerProfile = profile;
          }
        }
      }

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
        .populate("selectedLawyer", "fullName email mobile profileImage isVerified")
        .populate("proposals.lawyer", "fullName email mobile profileImage")
        .lean();

      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (caseItem.selectedLawyer) {
        const profile = await Lawyer.findOne({ user: caseItem.selectedLawyer._id }).lean();
        if (profile) {
          caseItem.selectedLawyerProfile = profile;
        }
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

  async acceptCaseRequest(req, res, next) {
    try {
      const { id } = req.params;
      const lawyerId = req.user._id;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (!caseItem.selectedLawyer || caseItem.selectedLawyer.toString() !== lawyerId.toString()) {
        return ApiResponse.error(res, "You are not the selected lawyer for this case.", 403);
      }

      caseItem.assignedLawyer = lawyerId;
      caseItem.status = "In Progress";

      // Complete In Progress milestone
      const inProgressMilestone = caseItem.milestones.find((m) => m.title === "In Progress");
      if (inProgressMilestone) {
        inProgressMilestone.isCompleted = true;
      }

      await caseItem.save();

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        io.of("/cases").to(lawyerId.toString()).emit("case_updated", caseItem);
      }

      return ApiResponse.success(res, "Case request accepted and lawyer assigned.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async rejectCaseRequest(req, res, next) {
    try {
      const { id } = req.params;
      const lawyerId = req.user._id;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (!caseItem.selectedLawyer || caseItem.selectedLawyer.toString() !== lawyerId.toString()) {
        return ApiResponse.error(res, "You are not the selected lawyer for this case.", 403);
      }

      caseItem.status = "Rejected";
      await caseItem.save();

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        io.of("/cases").to(lawyerId.toString()).emit("case_updated", caseItem);
      }

      return ApiResponse.success(res, "Case request rejected.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async getInProgressCases(req, res, next) {
    try {
      let query = {
        status: { $in: ["Awaiting Lawyer Acceptance", "In Progress"] }
      };
      if (req.user.role === "client") {
        query.client = req.user._id;
      } else if (req.user.role === "lawyer") {
        query.$or = [
          { assignedLawyer: req.user._id },
          { selectedLawyer: req.user._id }
        ];
      }

      const cases = await Case.find(query)
        .populate("client", "fullName email mobile profileImage")
        .populate("assignedLawyer", "fullName email mobile profileImage")
        .populate("selectedLawyer", "fullName email mobile profileImage isVerified")
        .populate("proposals.lawyer", "fullName email mobile profileImage")
        .sort({ updatedAt: -1 })
        .lean();

      for (let c of cases) {
        if (c.selectedLawyer) {
          const profile = await Lawyer.findOne({ user: c.selectedLawyer._id }).lean();
          if (profile) c.selectedLawyerProfile = profile;
        }
        if (c.assignedLawyer) {
          const profile = await Lawyer.findOne({ user: c.assignedLawyer._id }).lean();
          if (profile) c.assignedLawyerProfile = profile;
        }
      }

      return ApiResponse.success(res, "In-progress cases fetched successfully.", cases);
    } catch (error) {
      next(error);
    }
  }

  async getClosedCases(req, res, next) {
    try {
      let query = { status: "Closed" };
      if (req.user.role === "client") {
        query.client = req.user._id;
      } else if (req.user.role === "lawyer") {
        query.$or = [
          { assignedLawyer: req.user._id },
          { selectedLawyer: req.user._id }
        ];
      }

      const cases = await Case.find(query)
        .populate("client", "fullName email mobile profileImage")
        .populate("assignedLawyer", "fullName email mobile profileImage")
        .populate("selectedLawyer", "fullName email mobile profileImage isVerified")
        .populate("proposals.lawyer", "fullName email mobile profileImage")
        .sort({ updatedAt: -1 })
        .lean();

      for (let c of cases) {
        if (c.selectedLawyer) {
          const profile = await Lawyer.findOne({ user: c.selectedLawyer._id }).lean();
          if (profile) c.selectedLawyerProfile = profile;
        }
        if (c.assignedLawyer) {
          const profile = await Lawyer.findOne({ user: c.assignedLawyer._id }).lean();
          if (profile) c.assignedLawyerProfile = profile;
        }
      }

      return ApiResponse.success(res, "Closed cases fetched successfully.", cases);
    } catch (error) {
      next(error);
    }
  }

  async getCaseTimeline(req, res, next) {
    try {
      const { id } = req.params;
      const caseItem = await Case.findById(id).select("milestones status").lean();
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }
      return ApiResponse.success(res, "Case timeline fetched successfully.", {
        status: caseItem.status,
        milestones: caseItem.milestones || []
      });
    } catch (error) {
      next(error);
    }
  }

  async getCaseLawyer(req, res, next) {
    try {
      const { id } = req.params;
      const caseItem = await Case.findById(id)
        .populate("selectedLawyer", "fullName email mobile profileImage isVerified")
        .populate("assignedLawyer", "fullName email mobile profileImage isVerified")
        .lean();

      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      const targetUser = caseItem.assignedLawyer || caseItem.selectedLawyer;
      if (!targetUser) {
        return ApiResponse.success(res, "No lawyer associated with this case.", null);
      }

      const profile = await Lawyer.findOne({ user: targetUser._id }).lean();
      return ApiResponse.success(res, "Case lawyer fetched successfully.", {
        user: targetUser,
        profile: profile || null
      });
    } catch (error) {
      next(error);
    }
  }

  async submitCaseReview(req, res, next) {
    try {
      const { id } = req.params;
      const { rating, review } = req.body;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      caseItem.rating = Number(rating);
      caseItem.review = review;
      await caseItem.save();

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        if (caseItem.assignedLawyer) {
          io.of("/cases").to(caseItem.assignedLawyer.toString()).emit("case_updated", caseItem);
        }
      }

      return ApiResponse.success(res, "Review submitted successfully.", caseItem);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CaseController();
