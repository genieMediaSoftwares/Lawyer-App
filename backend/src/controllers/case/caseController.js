const Case = require("../../models/Case");
const User = require("../../models/User");
const Lawyer = require("../../models/Lawyer");
const Proposal = require("../../models/Proposal");
const ApiResponse = require("../../config/ApiResponse");
const notificationService = require("../../services/notification/notificationService");

const partyIds = (caseItem, keys) =>
  keys
    .map((key) => caseItem[key])
    .filter(Boolean)
    .map((value) => (value._id ? value._id : value).toString());

const canReadCase = (user, caseItem) => {
  if (user.role === "admin") return true;

  const userId = user._id.toString();

  if (user.role === "client") {
    return partyIds(caseItem, ["client"]).includes(userId);
  }

  if (user.role === "lawyer") {
    if (caseItem.status === "Submitted") return true;
    return partyIds(caseItem, ["assignedLawyer", "selectedLawyer"]).includes(
      userId
    );
  }

  return false;
};

const canManageHearings = (user, caseItem) => {
  if (user.role === "admin") return true;
  if (user.role !== "lawyer") return false;
  return partyIds(caseItem, ["assignedLawyer", "selectedLawyer"]).includes(
    user._id.toString()
  );
};

const syncNextHearing = (caseItem) => {
  const upcoming = (caseItem.hearings || [])
    .filter((h) => h.status === "scheduled" && h.date)
    .sort((a, b) => new Date(a.date) - new Date(b.date));

  caseItem.nextHearing = upcoming.length ? upcoming[0].date : null;
};

const emitCaseUpdated = (req, caseItem) => {
  const io = req.app.get("io");
  if (!io) return;

  for (const id of partyIds(caseItem, [
    "client",
    "assignedLawyer",
    "selectedLawyer",
  ])) {
    io.of("/cases").to(id).emit("case_updated", caseItem);
  }
};

class CaseController {
  async createCase(req, res, next) {
    try {
      const {
        title, description, category, subcategory, location, budgetRange,
        urgency, preferredCourt, documents, selectedLawyer, voiceUrl,
        voiceTranscript, city, district, state, country, latitude, longitude,
        placeId,
        incidentDate, opposingParty, firNumber, policeStation, bailDetails,
        claimAmount,
      } = req.body;
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
        locationPlaceId: placeId || "",

        incidentDate: incidentDate && !Number.isNaN(Date.parse(incidentDate))
          ? new Date(incidentDate)
          : null,
        opposingParty: opposingParty || "",
        firNumber: firNumber || "",
        policeStation: policeStation || "",
        bailDetails: bailDetails || "",
        claimAmount: claimAmount != null && Number.isFinite(Number(claimAmount))
          ? Number(claimAmount)
          : 0,
      });

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

      const io = req.app.get("io");
      if (io) {
        if (hasSelectedLawyer) {
          io.of("/cases").to(selectedLawyer.toString()).emit("case_updated", newCase);
        } else {
          io.of("/cases").emit("case_updated", newCase);
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

      if (!canReadCase(req.user, caseItem)) {
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

      const parsedFee = Number(feeProposal);
      const feeToUse = Number.isFinite(parsedFee) && parsedFee >= 0 ? parsedFee : 1500;

      let proposal = await Proposal.findOne({ caseId: id, lawyerId });
      if (proposal) {
        proposal.consultationFee = feeToUse;
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
          consultationFee: feeToUse,
          proposalMessage: message || "",
          estimatedResponseTime: estimatedResponseTime || "24 hours",
          consultationMode: consultationMode || "Video",
          availability: availability || "Mon-Fri 9AM-5PM",
          status: "Pending"
        });
      }

      const existingProposalIndex = caseItem.proposals.findIndex(
        (p) => p.lawyer.toString() === lawyerId.toString()
      );

      if (existingProposalIndex > -1) {
        caseItem.proposals[existingProposalIndex].feeProposal = feeToUse;
        caseItem.proposals[existingProposalIndex].message = message || "";
      } else {
        caseItem.proposals.push({
          lawyer: lawyerId,
          feeProposal: feeToUse,
          message: message || ""
        });
      }

      caseItem.status = "Interested";

      const proposalsMilestone = caseItem.milestones.find((m) => m.title === "Proposals Received");
      if (proposalsMilestone) {
        proposalsMilestone.isCompleted = true;
      }

      await caseItem.save();

      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: caseItem.client,
        type: "proposal_received",
        title: "Proposal Received",
        message: `An advocate has sent a proposal for your case: "${caseItem.title}".`,
        referenceId: caseItem._id.toString()
      });

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

      const inProgressMilestone = caseItem.milestones.find((m) => m.title === "In Progress");
      if (inProgressMilestone) {
        inProgressMilestone.isCompleted = true;
      }

      await caseItem.save();

      const Chat = require("../../models/Chat");
      let chat = await Chat.findOne({
        participants: { $all: [caseItem.client, lawyerId] }
      });
      if (!chat) {
        await Chat.create({
          participants: [caseItem.client, lawyerId],
          lastMessage: "Consultation accepted. You can now start messaging.",
          lastMessageAt: new Date()
        });
      }

      await notificationService.createAndSendNotification({
        senderId: caseItem.client,
        receiverId: lawyerId,
        type: "proposal_accepted",
        title: "Proposal Accepted",
        message: `Your proposal for the case: "${caseItem.title}" has been accepted!`,
        referenceId: caseItem._id.toString()
      });

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

      await notificationService.createAndSendNotification({
        senderId: caseItem.client,
        receiverId: lawyerId,
        type: "proposal_rejected",
        title: "Proposal Rejected",
        message: `Your proposal for the case: "${caseItem.title}" has been rejected.`,
        referenceId: caseItem._id.toString()
      });

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

      if (milestoneTitle === "Closed" && isCompleted) {
        caseItem.status = "Closed";
      }

      await caseItem.save();

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

      const isSelected = caseItem.selectedLawyer && caseItem.selectedLawyer.toString() === lawyerId.toString();
      const isGeneral = !caseItem.selectedLawyer && caseItem.status === "Submitted";

      if (!isSelected && !isGeneral) {
        return ApiResponse.error(res, "You are not authorized to accept this case request.", 403);
      }

      caseItem.assignedLawyer = lawyerId;
      caseItem.status = "Accepted";
      caseItem.acceptedAt = new Date();

      const inProgressMilestone = caseItem.milestones.find((m) => m.title === "In Progress");
      if (inProgressMilestone) {
        inProgressMilestone.isCompleted = true;
      }

      await caseItem.save();

      const Chat = require("../../models/Chat");
      let chat = await Chat.findOne({
        participants: { $all: [caseItem.client, lawyerId] }
      });
      if (!chat) {
        await Chat.create({
          participants: [caseItem.client, lawyerId],
          lastMessage: "Consultation accepted. You can now start messaging.",
          lastMessageAt: new Date()
        });
      }

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

      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: caseItem.client,
        type: "proposal_rejected",
        title: "Case Request Rejected",
        message: `Your case request has been rejected by the advocate.`,
        referenceId: caseItem._id.toString()
      });

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

  async addHearing(req, res, next) {
    try {
      const { id } = req.params;
      const { date, timeSlot, court, purpose, status, notes } = req.body;

      if (!date) {
        return ApiResponse.error(res, "Hearing date is required.", 400);
      }

      const hearingDate = new Date(date);
      if (Number.isNaN(hearingDate.getTime())) {
        return ApiResponse.error(res, "Hearing date is not a valid date.", 400);
      }

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (!canManageHearings(req.user, caseItem)) {
        return ApiResponse.error(
          res,
          "You are not assigned to this case.",
          403
        );
      }

      caseItem.hearings.push({
        date: hearingDate,
        timeSlot: timeSlot || "",
        court: court || caseItem.preferredCourt || "",
        purpose: purpose || "",
        status: status || "scheduled",
        notes: notes || "",
        createdBy: req.user._id,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      syncNextHearing(caseItem);
      await caseItem.save();

      try {
        if (caseItem.client) {
          await notificationService.createAndSendNotification({
            senderId: req.user._id,
            receiverId: caseItem.client,
            type: "case_update",
            title: "Hearing Scheduled",
            message: `A hearing on "${caseItem.title}" is listed for ${hearingDate.toDateString()}.`,
            referenceId: caseItem._id.toString(),
          });
        }
      } catch (notifyError) {
        console.error(
          "⚠️ hearing notification failed:",
          notifyError.message
        );
      }

      emitCaseUpdated(req, caseItem);

      return ApiResponse.success(
        res,
        "Hearing added successfully.",
        caseItem,
        201
      );
    } catch (error) {
      next(error);
    }
  }

  async updateHearing(req, res, next) {
    try {
      const { id, hearingId } = req.params;
      const { date, timeSlot, court, purpose, status, notes } = req.body;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (!canManageHearings(req.user, caseItem)) {
        return ApiResponse.error(
          res,
          "You are not assigned to this case.",
          403
        );
      }

      const hearing = caseItem.hearings.id(hearingId);
      if (!hearing) {
        return ApiResponse.error(res, "Hearing not found.", 404);
      }

      if (date !== undefined) {
        const hearingDate = new Date(date);
        if (Number.isNaN(hearingDate.getTime())) {
          return ApiResponse.error(res, "Hearing date is not a valid date.", 400);
        }
        hearing.date = hearingDate;
      }

      if (timeSlot !== undefined) hearing.timeSlot = timeSlot;
      if (court !== undefined) hearing.court = court;
      if (purpose !== undefined) hearing.purpose = purpose;
      if (status !== undefined) hearing.status = status;
      if (notes !== undefined) hearing.notes = notes;
      hearing.updatedAt = new Date();

      syncNextHearing(caseItem);
      await caseItem.save();

      emitCaseUpdated(req, caseItem);

      return ApiResponse.success(res, "Hearing updated successfully.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async deleteHearing(req, res, next) {
    try {
      const { id, hearingId } = req.params;

      const caseItem = await Case.findById(id);
      if (!caseItem) {
        return ApiResponse.error(res, "Case not found.", 404);
      }

      if (!canManageHearings(req.user, caseItem)) {
        return ApiResponse.error(
          res,
          "You are not assigned to this case.",
          403
        );
      }

      const hearing = caseItem.hearings.id(hearingId);
      if (!hearing) {
        return ApiResponse.error(res, "Hearing not found.", 404);
      }

      hearing.deleteOne();

      syncNextHearing(caseItem);
      await caseItem.save();

      emitCaseUpdated(req, caseItem);

      return ApiResponse.success(res, "Hearing removed successfully.", caseItem);
    } catch (error) {
      next(error);
    }
  }

  async getMyHearings(req, res, next) {
    try {
      if (req.user.role !== "lawyer") {
        return ApiResponse.error(res, "Access forbidden.", 403);
      }

      const cases = await Case.find({
        $or: [
          { assignedLawyer: req.user._id },
          { selectedLawyer: req.user._id },
        ],
        "hearings.0": { $exists: true },
      })
        .populate("client", "fullName profileImage")
        .select("title category status client hearings")
        .lean();

      const hearings = [];
      for (const caseItem of cases) {
        for (const hearing of caseItem.hearings || []) {
          hearings.push({
            ...hearing,
            caseId: caseItem._id,
            caseTitle: caseItem.title,
            caseCategory: caseItem.category,
            caseStatus: caseItem.status,
            clientId: caseItem.client ? caseItem.client._id : null,
            clientName: caseItem.client ? caseItem.client.fullName : "",
            clientImage: caseItem.client ? caseItem.client.profileImage : "",
          });
        }
      }

      hearings.sort((a, b) => new Date(a.date) - new Date(b.date));

      return ApiResponse.success(
        res,
        "Hearings fetched successfully.",
        hearings
      );
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CaseController();
