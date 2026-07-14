const Case = require("../../models/Case");
const User = require("../../models/User");
const Lawyer = require("../../models/Lawyer");
const Proposal = require("../../models/Proposal");
const ApiResponse = require("../../config/ApiResponse");
const notificationService = require("../../services/notification/notificationService");

class CaseController {
  async createCase(req, res, next) {
    try {
      const { title, description, category, subcategory, location, budgetRange, urgency, preferredCourt, documents, selectedLawyer, voiceUrl, voiceTranscript, city, district, state, country, latitude, longitude } = req.body;
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
        milestones,
        voiceUrl: voiceUrl || "",
        voiceTranscript: voiceTranscript || "",
        locationCity: city || "",
        locationDistrict: district || "",
        locationState: state || "",
        locationCountry: country || "",
        locationLatitude: latitude ? Number(latitude) : 0.0,
        locationLongitude: longitude ? Number(longitude) : 0.0,
      });

      // Trigger notifications for new case posted
      if (hasSelectedLawyer) {
        await notificationService.createAndSendNotification({
          senderId: client,
          receiverId: selectedLawyer,
          type: "case_posted",
          title: "New Case Request",
          message: `You received a direct case request: "${title}".`,
          referenceId: newCase._id.toString()
        });
      } else {
        const lawyers = await User.find({ role: "lawyer" });
        for (const lawyer of lawyers) {
          await notificationService.createAndSendNotification({
            senderId: client,
            receiverId: lawyer._id,
            type: "case_posted",
            title: "New Case Posted",
            message: `A new case matching your specialization was posted: "${title}".`,
            referenceId: newCase._id.toString()
          });
        }
      }

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
      const { 
        feeProposal, 
        message, 
        estimatedResponseTime, 
        consultationMode, 
        availability 
      } = req.body;
      const lawyerId = req.user._id;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      // 1. Create or update in Proposal collection
      let proposal = await Proposal.findOne({ caseId: id, lawyerId });
      if (proposal) {
        proposal.consultationFee = feeProposal || 1500;
        proposal.proposalMessage = message || "";
        proposal.estimatedResponseTime = estimatedResponseTime || "24 hours";
        proposal.consultationMode = consultationMode || "Video";
        proposal.availability = availability || "Mon-Fri 9AM-5PM";
        await proposal.save();
      } else {
        proposal = await Proposal.create({
          caseId: id,
          lawyerId,
          clientId: caseItem.client,
          consultationFee: feeProposal || 1500,
          proposalMessage: message || "",
          estimatedResponseTime: estimatedResponseTime || "24 hours",
          consultationMode: consultationMode || "Video",
          availability: availability || "Mon-Fri 9AM-5PM",
          status: "Pending"
        });
      }

      // 2. Add to Case proposals subdocument array for compatibility
      const existingProposalIndex = caseItem.proposals.findIndex(
        (p) => p.lawyer.toString() === lawyerId.toString()
      );

      if (existingProposalIndex > -1) {
        caseItem.proposals[existingProposalIndex].feeProposal = feeProposal || 1500;
        caseItem.proposals[existingProposalIndex].message = message || "";
      } else {
        caseItem.proposals.push({
          lawyer: lawyerId,
          feeProposal: feeProposal || 1500,
          message: message || ""
        });
      }

      // 3. Move status to Interested
      caseItem.status = "Interested";

      // Set Proposals Received milestone to true
      const proposalsMilestone = caseItem.milestones.find((m) => m.title === "Proposals Received");
      if (proposalsMilestone) {
        proposalsMilestone.isCompleted = true;
      }

      await caseItem.save();

      // 4. Create Notification for Client (Proposal Received)
      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: caseItem.client,
        type: "proposal_received",
        title: "Proposal Received",
        message: `An advocate has sent a proposal for your case: "${caseItem.title}".`,
        referenceId: caseItem._id.toString()
      });

      // 5. Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        io.of("/cases").to(lawyerId.toString()).emit("case_updated", caseItem);
      }

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

      // Create Notification for Lawyer (Proposal Accepted)
      await notificationService.createAndSendNotification({
        senderId: caseItem.client,
        receiverId: lawyerId,
        type: "proposal_accepted",
        title: "Proposal Accepted",
        message: `Your proposal for the case: "${caseItem.title}" has been accepted!`,
        referenceId: caseItem._id.toString()
      });

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        io.of("/cases").to(lawyerId.toString()).emit("case_updated", caseItem);
      }

      return ApiResponse.success(res, "Proposal accepted and lawyer assigned.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async rejectProposal(req, res, next) {
    try {
      const { id } = req.params;
      const { lawyerId } = req.body;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      caseItem.status = "Rejected";
      await caseItem.save();

      // Create Notification for Lawyer (Proposal Rejected)
      await notificationService.createAndSendNotification({
        senderId: caseItem.client,
        receiverId: lawyerId,
        type: "proposal_rejected",
        title: "Proposal Rejected",
        message: `Your proposal for the case: "${caseItem.title}" has been rejected.`,
        referenceId: caseItem._id.toString()
      });

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        io.of("/cases").to(lawyerId.toString()).emit("case_updated", caseItem);
      }

      return ApiResponse.success(res, "Proposal rejected successfully.", caseItem);
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

      // Trigger notification for case status/milestone update
      const notifyUser = req.user.role === "client" ? caseItem.assignedLawyer : caseItem.client;
      if (notifyUser) {
        await notificationService.createAndSendNotification({
          senderId: req.user._id,
          receiverId: notifyUser,
          type: "case_status_updated",
          title: "Milestone Updated",
          message: `The milestone "${milestoneTitle}" has been updated for case: "${caseItem.title}".`,
          referenceId: caseItem._id.toString()
        });
      }

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
      caseItem.status = "Accepted";
      caseItem.acceptedAt = new Date();

      // Complete In Progress milestone
      const inProgressMilestone = caseItem.milestones.find((m) => m.title === "In Progress");
      if (inProgressMilestone) {
        inProgressMilestone.isCompleted = true;
      }

      await caseItem.save();

      // Create notifications
      await notificationService.createAndSendNotification({
        senderId: caseItem.client,
        receiverId: lawyerId,
        type: "proposal_accepted",
        title: "Case Request Accepted",
        message: "You have accepted a new case request.",
        referenceId: caseItem._id.toString()
      });

      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: caseItem.client,
        type: "proposal_accepted",
        title: "Case Request Accepted",
        message: "Your selected lawyer has accepted your case request.",
        referenceId: caseItem._id.toString()
      });

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

      // Notify client that lawyer rejected the request
      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: caseItem.client,
        type: "proposal_rejected",
        title: "Case Request Rejected",
        message: `Your case request has been rejected by the advocate.`,
        referenceId: caseItem._id.toString()
      });

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

  async startCase(req, res, next) {
    try {
      const { id } = req.params;
      const lawyerId = req.user._id;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (!caseItem.assignedLawyer || caseItem.assignedLawyer.toString() !== lawyerId.toString()) {
        return ApiResponse.error(res, "You are not assigned to this case.", 403);
      }

      caseItem.status = "In Progress";
      caseItem.startedAt = new Date();
      await caseItem.save();

      // Create notifications
      await notificationService.createAndSendNotification({
        senderId: caseItem.client,
        receiverId: lawyerId,
        type: "case_status_updated",
        title: "Case Started",
        message: `You have started working on case: "${caseItem.title}".`,
        referenceId: caseItem._id.toString()
      });

      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: caseItem.client,
        type: "case_status_updated",
        title: "Case Started",
        message: `Your lawyer has started working on your case: "${caseItem.title}".`,
        referenceId: caseItem._id.toString()
      });

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        io.of("/cases").to(lawyerId.toString()).emit("case_updated", caseItem);
      }

      return ApiResponse.success(res, "Case started successfully.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async markCaseCompleted(req, res, next) {
    try {
      const { id } = req.params;
      const lawyerId = req.user._id;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (!caseItem.assignedLawyer || caseItem.assignedLawyer.toString() !== lawyerId.toString()) {
        return ApiResponse.error(res, "You are not assigned to this case.", 403);
      }

      caseItem.status = "Completed";
      caseItem.completedAt = new Date();
      await caseItem.save();

      // Create notifications
      await notificationService.createAndSendNotification({
        senderId: caseItem.client,
        receiverId: lawyerId,
        type: "case_status_updated",
        title: "Case Completed",
        message: `You have marked the case as completed: "${caseItem.title}".`,
        referenceId: caseItem._id.toString()
      });

      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: caseItem.client,
        type: "case_status_updated",
        title: "Case Completed",
        message: `Your lawyer has marked your case as completed: "${caseItem.title}".`,
        referenceId: caseItem._id.toString()
      });

      // Emit real-time case update
      const io = req.app.get("io");
      if (io) {
        io.of("/cases").to(caseItem.client.toString()).emit("case_updated", caseItem);
        io.of("/cases").to(lawyerId.toString()).emit("case_updated", caseItem);
      }

      return ApiResponse.success(res, "Case marked completed successfully.", caseItem);
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
