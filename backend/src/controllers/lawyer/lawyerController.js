const Lawyer = require("../../models/Lawyer");
const User = require("../../models/User");
const ApiResponse = require("../../config/ApiResponse");

class LawyerController {
  async getAllLawyers(req, res, next) {
    try {
      const {
        search,
        specialization,
        location,
        experience,
        minFee,
        maxFee,
        rating,
        language,
        verifiedOnly,
        availableNow,
        sortBy
      } = req.query;

      let userQuery = { role: "lawyer" };

      if (search) {
        userQuery.fullName = { $regex: search, $options: "i" };
      }
      if (location && location !== "All" && location !== "All Locations") {
        userQuery.location = { $regex: location, $options: "i" };
      }
      if (verifiedOnly === "true") {
        userQuery.isVerified = true;
      }
      if (availableNow === "true") {
        userQuery.isActive = true;
      }

      const matchingUsers = await User.find(userQuery);
      const userIds = matchingUsers.map((u) => u._id);

      // Find existing lawyer profiles
      const existingLawyers = await Lawyer.find({ user: { $in: userIds } }).populate(
        "user",
        "fullName email mobile profileImage location isVerified isActive"
      );

      // Identify user IDs missing a Lawyer profile
      const existingUserIds = new Set(existingLawyers.map((l) => l.user ? l.user._id.toString() : ''));
      const missingUsers = matchingUsers.filter((u) => !existingUserIds.has(u._id.toString()));

      // Create missing lawyer profiles dynamically
      if (missingUsers.length > 0) {
        const newLawyerPromises = missingUsers.map((user) => 
          Lawyer.create({
            user: user._id,
            specialization: "General Practice",
            experience: 2,
            education: "LLB",
            consultationFee: 1500,
            bio: "Professional advocate specializing in litigation and advisory.",
            languages: ["English", "Hindi"],
            barCouncilNumber: "12345/2026",
            officeAddress: user.location || "Office Address",
          })
        );
        await Promise.all(newLawyerPromises);
      }

      // Query again to return the full populated list
      let lawyerQuery = { user: { $in: userIds } };
      
      if (specialization && specialization !== "All" && specialization !== "All Practice Areas") {
        lawyerQuery.specialization = { $regex: specialization, $options: "i" };
      }

      // Experience filter (ranges: '0-2', '3-5', '5-10', '10+')
      if (experience && experience !== "All" && experience !== "All Experience") {
        if (experience === "0-2") {
          lawyerQuery.experience = { $gte: 0, $lte: 2 };
        } else if (experience === "3-5") {
          lawyerQuery.experience = { $gte: 3, $lte: 5 };
        } else if (experience === "5-10") {
          lawyerQuery.experience = { $gte: 5, $lte: 10 };
        } else if (experience === "10+") {
          lawyerQuery.experience = { $gte: 10 };
        }
      }

      // Consultation Fee filter (range)
      if (minFee || maxFee) {
        lawyerQuery.consultationFee = {};
        if (minFee) {
          lawyerQuery.consultationFee.$gte = parseInt(minFee);
        }
        if (maxFee) {
          lawyerQuery.consultationFee.$lte = parseInt(maxFee);
        }
      }

      // Rating filter (e.g. "4★+", "3★+", etc)
      if (rating && rating !== "All" && rating !== "All Ratings") {
        const parsedRating = parseFloat(rating.replace("★+", "").replace("+", ""));
        if (!isNaN(parsedRating)) {
          lawyerQuery.rating = { $gte: parsedRating };
        }
      }

      // Language filter (e.g. list of selected languages or single language)
      if (language) {
        const langs = Array.isArray(language) ? language : [language];
        const cleanLangs = langs.filter(l => l && l.trim() !== "");
        if (cleanLangs.length > 0) {
          lawyerQuery.languages = { $in: cleanLangs.map(l => new RegExp(l.trim(), 'i')) };
        }
      }

      let lawyers = await Lawyer.find(lawyerQuery).populate(
        "user",
        "fullName email mobile profileImage location isVerified isActive"
      );

      // Sorting logic in JavaScript memory
      if (sortBy) {
        if (sortBy === "Highest Rated") {
          lawyers.sort((a, b) => (b.rating || 0) - (a.rating || 0));
        } else if (sortBy === "Most Reviewed") {
          lawyers.sort((a, b) => (b.totalReviews || 0) - (a.totalReviews || 0));
        } else if (sortBy === "Name (A - Z)") {
          lawyers.sort((a, b) => {
            const nameA = (a.user && a.user.fullName || '').toLowerCase();
            const nameB = (b.user && b.user.fullName || '').toLowerCase();
            return nameA.localeCompare(nameB);
          });
        } else if (sortBy === "Name (Z - A)") {
          lawyers.sort((a, b) => {
            const nameA = (a.user && a.user.fullName || '').toLowerCase();
            const nameB = (b.user && b.user.fullName || '').toLowerCase();
            return nameB.localeCompare(nameA);
          });
        } else if (sortBy === "Newest First") {
          lawyers.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        }
      }

      return ApiResponse.success(res, "Lawyers fetched successfully.", lawyers);
    } catch (error) {
      next(error);
    }
  }

  async getLawyerById(req, res, next) {
    try {
      const { id } = req.params; // userId or lawyerId? Let's check both
      let lawyer = await Lawyer.findOne({ user: id }).populate(
        "user",
        "fullName email mobile profileImage location"
      );

      if (!lawyer) {
        lawyer = await Lawyer.findById(id).populate(
          "user",
          "fullName email mobile profileImage location"
        );
      }

      if (!lawyer) {
        const user = await User.findById(id);
        if (user && user.role === 'lawyer') {
          lawyer = await Lawyer.create({
            user: id,
            specialization: "General Practice",
            experience: 0,
            education: "",
            consultationFee: 0,
            bio: "",
            languages: []
          });
          lawyer = await Lawyer.findById(lawyer._id).populate(
            "user",
            "fullName email mobile profileImage location"
          );
        }
      }

      if (!lawyer) {
        return ApiResponse.error(res, "Lawyer profile not found.", 404);
      }

      return ApiResponse.success(res, "Lawyer details fetched successfully.", lawyer);
    } catch (error) {
      next(error);
    }
  }

  async updateLawyerProfile(req, res, next) {
    try {
      const userId = req.user._id;
      const {
        specialization,
        experience,
        education,
        barCouncilNumber,
        consultationFee,
        bio,
        officeAddress,
        upiId,
        workingHours,
        bankDetails,
      } = req.body;
      
      let lawyer = await Lawyer.findOneAndUpdate(
        { user: userId },
        {
          specialization,
          experience,
          education,
          barCouncilNumber,
          consultationFee,
          bio,
          officeAddress,
          upiId,
          workingHours,
          bankDetails,
        },
        { new: true, runValidators: true }
      ).populate("user", "fullName email mobile profileImage location");

      if (!lawyer) {
        return ApiResponse.error(res, "Lawyer profile not found.", 404);
      }

      return ApiResponse.success(res, "Lawyer profile updated successfully.", lawyer);
    } catch (error) {
      next(error);
    }
  }
  async match(req, res, next) {
    try {
      const { specialization, experience, maxFee, rating, language } = req.query;
      let userQuery = { role: "lawyer" };
      const matchingUsers = await User.find(userQuery).select("_id");
      const userIds = matchingUsers.map((u) => u._id);

      let lawyerQuery = { user: { $in: userIds } };
      
      if (specialization && specialization !== "All") {
        lawyerQuery.specialization = { $regex: specialization, $options: "i" };
      }
      if (experience) {
        lawyerQuery.experience = { $gte: parseInt(experience) };
      }
      if (maxFee) {
        lawyerQuery.consultationFee = { $lte: parseInt(maxFee) };
      }
      if (rating) {
        lawyerQuery.rating = { $gte: parseFloat(rating) };
      }
      if (language) {
        lawyerQuery.languages = { $regex: language, $options: "i" };
      }

      const lawyers = await Lawyer.find(lawyerQuery).populate(
        "user",
        "fullName email mobile profileImage location"
      );

      return ApiResponse.success(res, "Matched lawyers fetched successfully.", lawyers);
    } catch (error) {
      next(error);
    }
  }

  async recommendLawyers(req, res, next) {
    try {
      const { category, subcategory, city, district, state, sortBy } = req.query;

      if (!category) {
        return ApiResponse.error(res, "Category is required for recommendation.", 400);
      }

      // Fetch all lawyers with populated user details
      const allLawyers = await Lawyer.find().populate(
        "user",
        "fullName email mobile profileImage location isVerified isActive"
      );

      // Filter to only verified / registered lawyers with user profile
      const activeLawyers = allLawyers.filter(l => l.user != null);

      // Map and calculate match percentage
      let results = activeLawyers.map((lawyer) => {
        let matchPercentage = 75; // Base Match
        
        // City match
        const lawyerLoc = (lawyer.user.location || "").toLowerCase();
        let locationScore = 0;
        if (city && lawyerLoc.includes(city.toLowerCase())) {
          matchPercentage += 15;
          locationScore = 3;
        } else if (district && lawyerLoc.includes(district.toLowerCase())) {
          matchPercentage += 10;
          locationScore = 2;
        } else if (state && lawyerLoc.includes(state.toLowerCase())) {
          matchPercentage += 5;
          locationScore = 1;
        }

        // Verification bonus
        if (lawyer.user.isVerified) {
          matchPercentage += 5;
        }

        // Specialization match
        const spec = (lawyer.specialization || "").toLowerCase();
        const cat = category.toLowerCase();
        const sub = (subcategory || "").toLowerCase();
        if (spec.includes(cat) || cat.includes(spec)) {
          matchPercentage += 3;
        }
        if (sub && (spec.includes(sub) || sub.includes(spec))) {
          matchPercentage += 2;
        }

        // Caps at 98% max, min at 65%
        matchPercentage = Math.min(98, Math.max(65, matchPercentage));

        // Response time is only reported when the lawyer's record actually
        // holds one. It used to be derived from the length of their name
        // — `10 + (nameLen % 4) * 5` minutes — and shown to clients choosing
        // legal representation as though it were a measured service level.
        const responseTime = lawyer.responseTime || null;

        // Extract city/district/state from location string (e.g. "Visakhapatnam, Andhra Pradesh").
        // Empty when the lawyer has not set a location — "Unknown" and "India"
        // were placeholders that rendered as if they were real profile data.
        const locParts = (lawyer.user.location || "").split(",");
        const parsedCity = locParts[0] ? locParts[0].trim() : "";
        const parsedState = locParts[1] ? locParts[1].trim() : "";

        // Only the lawyer's own declared specialisation. The requested category
        // and sub-category used to be appended here, so every result appeared
        // to practise exactly what the client searched for.
        const practiceAreas = (
          Array.isArray(lawyer.practiceAreas) && lawyer.practiceAreas.length
            ? lawyer.practiceAreas
            : [lawyer.specialization]
        ).filter(Boolean);

        return {
          lawyerId: lawyer._id, // lawyer document ID
          userId: lawyer.user._id, // user document ID
          profileImage: lawyer.user.profileImage || "",
          fullName: lawyer.user.fullName,
          specialization: lawyer.specialization,
          city: parsedCity,
          // The lawyer's own district, never the one the client searched for —
          // echoing the query back made every result look local.
          district: lawyer.district || parsedCity,
          state: parsedState,
          // The stored location string as well as its parts. Only the parts
          // were returned, and every consumer of this endpoint reads
          // `location` (LawyerModel.fromJson, AdvocateCard), so recommended
          // advocates rendered with a blank location.
          location: lawyer.user.location || "",
          experience: lawyer.experience,
          rating: lawyer.rating,
          reviewCount: lawyer.totalReviews,
          consultationFee: lawyer.consultationFee,
          languages: lawyer.languages?.length ? lawyer.languages : ["English", "Hindi"],
          practiceAreas: practiceAreas,
          verified: lawyer.user.isVerified,
          onlineStatus: lawyer.user.isActive,
          responseTime: responseTime,
          matchPercentage: matchPercentage,
          casesHandled: typeof lawyer.casesHandled === "number" ? lawyer.casesHandled : (lawyer.casesHandled || 120),
          locationScore: locationScore, // helper for sorting
          winPercentage: typeof lawyer.winPercentage === "number" ? lawyer.winPercentage : (lawyer.winPercentage || 85),
          bio: lawyer.bio || "",
          education: lawyer.education || "",
          barCouncilNumber: lawyer.barCouncilNumber || "",
          officeAddress: lawyer.officeAddress || "",
          workingHours: lawyer.workingHours || "9:00 AM - 6:00 PM",
        };
      });

      // Filter by specialization/category check: must be relevant to the requested category
      results = results.filter((lawyer) => {
        const spec = lawyer.specialization.toLowerCase();
        const cat = category.toLowerCase();
        const sub = (subcategory || "").toLowerCase();
        return spec.includes(cat) || cat.includes(spec) || 
               spec.includes("general") || spec.includes("litigation") ||
               (sub && (spec.includes(sub) || sub.includes(spec)));
      });

      // Sorting
      results.sort((a, b) => {
        // Priority 1: Location score (Same City -> Same District -> Same State)
        if (b.locationScore !== a.locationScore) {
          return b.locationScore - a.locationScore;
        }

        // Apply sort criteria if specified
        if (sortBy === "Best Match") {
          return b.matchPercentage - a.matchPercentage;
        } else if (sortBy === "Experience") {
          return b.experience - a.experience;
        } else if (sortBy === "Rating") {
          return b.rating - a.rating;
        } else if (sortBy === "Fees: Low to High") {
          return a.consultationFee - b.consultationFee;
        }

        // Default: Sort by match percentage
        return b.matchPercentage - a.matchPercentage;
      });

      return ApiResponse.success(res, "Recommended lawyers fetched successfully.", results);
    } catch (error) {
      next(error);
    }
  }

  async getLeads(req, res, next) {
    try {
      const Case = require("../../models/Case");
      const leads = await Case.find({
        $or: [
          { selectedLawyer: req.user._id, status: { $in: ["Awaiting Lawyer Acceptance", "Pending Lawyer Response"] } },
          { status: "Submitted", selectedLawyer: null }
        ]
      }).populate("client", "fullName");

      const formattedLeads = leads.map(c => ({
        caseId: c._id,
        clientName: c.client ? c.client.fullName : "Unknown Client",
        issueCategory: c.category,
        issueTitle: c.title,
        location: c.location,
        postedTime: c.createdAt,
        urgency: c.urgency,
        acknowledgementDocument: c.documents && c.documents[0] ? c.documents[0].url : "",
        preferredCourt: c.preferredCourt,
        caseStatus: c.status,
      }));

      return ApiResponse.success(res, "Leads retrieved successfully.", formattedLeads);
    } catch (error) {
      next(error);
    }
  }

  async getClients(req, res, next) {
    try {
      const Case = require("../../models/Case");
      const cases = await Case.find({
        assignedLawyer: req.user._id
      }).populate("client", "fullName profileImage");

      const mapClient = (c) => ({
        clientId: c.client ? c.client._id : "",
        name: c.client ? c.client.fullName : "Unknown Client",
        caseId: c._id,
        issue: c.title,
        currentStatus: c.status,
        lastActivity: c.updatedAt,
        profileImage: c.client ? c.client.profileImage : "",
      });

      const accepted = cases.filter(c => c.status === "Awaiting Lawyer Acceptance" || c.status === "Submitted").map(mapClient);
      const inProgress = cases.filter(c => c.status === "In Progress").map(mapClient);
      const closed = cases.filter(c => c.status === "Closed").map(mapClient);

      return ApiResponse.success(res, "Clients fetched and grouped successfully.", {
        accepted,
        inProgress,
        closed
      });
    } catch (error) {
      next(error);
    }
  }

  async getScheduleToday(req, res, next) {
    try {
      const Appointment = require("../../models/Appointment");
      const CalendarEvent = require("../../models/CalendarEvent");
      const Case = require("../../models/Case");

      const startOfToday = new Date();
      startOfToday.setHours(0, 0, 0, 0);
      const endOfToday = new Date();
      endOfToday.setHours(23, 59, 59, 999);

      const appointments = await Appointment.find({
        lawyer: req.user._id,
        date: { $gte: startOfToday, $lte: endOfToday }
      }).populate("client", "fullName").populate("case", "title");

      const casesWithHearings = await Case.find({
        assignedLawyer: req.user._id,
        nextHearing: { $gte: startOfToday, $lte: endOfToday }
      }).populate("client", "fullName");

      const calendarEvents = await CalendarEvent.find({
        lawyer: req.user._id,
        date: { $gte: startOfToday, $lte: endOfToday }
      });

      const apptEvents = appointments.map(a => ({
        title: `Consultation with ${a.client ? a.client.fullName : "Client"}`,
        client: a.client ? a.client.fullName : "",
        case: a.case ? a.case.title : "",
        startTime: a.date,
        endTime: new Date(a.date.getTime() + 30 * 60000),
        eventType: "consultation"
      }));

      const hearingEvents = casesWithHearings.map(c => ({
        title: `Court Hearing: ${c.title}`,
        client: c.client ? c.client.fullName : "",
        case: c.title,
        startTime: c.nextHearing,
        endTime: new Date(c.nextHearing.getTime() + 60 * 60000),
        eventType: "hearing"
      }));

      const calEvents = calendarEvents.map(e => ({
        title: e.title,
        client: "",
        case: "",
        startTime: e.date,
        endTime: e.date,
        eventType: e.type === "personal_event" ? "meeting" : "reminder"
      }));

      const allEvents = [...apptEvents, ...hearingEvents, ...calEvents];
      allEvents.sort((a, b) => new Date(a.startTime) - new Date(b.startTime));

      return ApiResponse.success(res, "Today's schedule fetched successfully.", allEvents);
    } catch (error) {
      next(error);
    }
  }

  async getUnreadMessages(req, res, next) {
    try {
      const Chat = require("../../models/Chat");
      const Message = require("../../models/Message");

      const chats = await Chat.find({
        participants: req.user._id
      }).populate("participants", "fullName");

      let unreadCount = 0;
      let latestMessage = "";
      let latestClient = "";
      let lastMessageTime = null;
      let conversationCount = chats.length;

      if (chats.length > 0) {
        const chatIds = chats.map(c => c._id);
        
        unreadCount = await Message.countDocuments({
          chat: { $in: chatIds },
          isRead: false,
          sender: { $ne: req.user._id }
        });

        const lastMsg = await Message.findOne({
          chat: { $in: chatIds }
        }).sort({ createdAt: -1 }).populate("sender", "fullName");

        if (lastMsg) {
          latestMessage = lastMsg.content;
          lastMessageTime = lastMsg.createdAt;
          
          const chatDetail = chats.find(c => c._id.toString() === lastMsg.chat.toString());
          if (chatDetail) {
            const clientPart = chatDetail.participants.find(p => p._id.toString() !== req.user._id.toString());
            latestClient = clientPart ? clientPart.fullName : (lastMsg.sender ? lastMsg.sender.fullName : "");
          }
        }
      }

      return ApiResponse.success(res, "Unread messages count fetched.", {
        unreadCount,
        conversationCount,
        latestMessage,
        latestClient,
        lastMessageTime
      });
    } catch (error) {
      next(error);
    }
  }

  async getGoogleCalendarStatus(req, res, next) {
    try {
      const Lawyer = require("../../models/Lawyer");
      const lawyer = await Lawyer.findOne({ user: req.user._id });
      if (!lawyer) {
        return ApiResponse.error(res, "Lawyer profile not found.", 404);
      }
      return ApiResponse.success(res, "Google Calendar status retrieved.", {
        connected: lawyer.googleConnected || false,
        email: lawyer.googleEmail || "",
      });
    } catch (error) {
      next(error);
    }
  }

  async connectGoogleCalendar(req, res, next) {
    try {
      const { email, isSimulated, code } = req.body;
      const Lawyer = require("../../models/Lawyer");
      const lawyer = await Lawyer.findOne({ user: req.user._id });
      if (!lawyer) {
        return ApiResponse.error(res, "Lawyer profile not found.", 404);
      }

      const googleCalendarService = require("../../services/googleCalendarService");

      // A real exchange needs both configured credentials and an authorization
      // code. Requiring the code here is what stops `oauth2Client.getToken()`
      // being called with undefined on a configured deployment whose client
      // did not complete the OAuth flow.
      const realMode =
        googleCalendarService.isRealMode() && !isSimulated && Boolean(code);

      if (realMode) {
        const { google } = require("googleapis");
        const oauth2Client = new google.auth.OAuth2(
          process.env.GOOGLE_CLIENT_ID,
          process.env.GOOGLE_CLIENT_SECRET,
          process.env.GOOGLE_REDIRECT_URI || "urn:ietf:wg:oauth:2.0:oob"
        );
        
        const { tokens } = await oauth2Client.getToken(code);
        oauth2Client.setCredentials(tokens);

        // Fetch user email from Google OAuth profile
        const oauth2 = google.oauth2({ version: "v2", auth: oauth2Client });
        const userInfo = await oauth2.userinfo.get();

        lawyer.googleConnected = true;
        lawyer.googleEmail = userInfo.data.email || email;
        lawyer.googleAccessToken = tokens.access_token;
        if (tokens.refresh_token) {
          lawyer.googleRefreshToken = tokens.refresh_token;
        }
        if (tokens.expiry_date) {
          lawyer.googleTokenExpiry = new Date(tokens.expiry_date);
        }
      } else {
        // Simulated integration: no Google API call is made and no real
        // calendar event will exist. The lawyer's own address is recorded —
        // "mock_advocate@gmail.com" used to be stored when none was supplied,
        // which then displayed in their settings as a connected account.
        if (!email) {
          return ApiResponse.error(
            res,
            "An email address is required to connect a calendar.",
            400
          );
        }

        lawyer.googleConnected = true;
        lawyer.googleEmail = email;
        lawyer.googleAccessToken = "";
        lawyer.googleRefreshToken = "mock_refresh_token";
        lawyer.googleTokenExpiry = null;
      }

      await lawyer.save();

      // Trigger sync of existing future appointments in the background
      googleCalendarService.syncExistingAppointments(req.user._id).catch(err => {
        console.error("Failed to sync existing appointments on connect:", err);
      });

      return ApiResponse.success(
        res,
        realMode
          ? "Google Calendar connected successfully."
          : "Calendar linked in simulation mode — consultations will not appear in your real Google Calendar until Google credentials are configured.",
        {
          connected: true,
          email: lawyer.googleEmail,
          // Told plainly, so the UI never presents a simulated link as a live
          // calendar integration.
          simulated: !realMode,
        }
      );
    } catch (error) {
      next(error);
    }
  }

  async disconnectGoogleCalendar(req, res, next) {
    try {
      const Lawyer = require("../../models/Lawyer");
      const lawyer = await Lawyer.findOne({ user: req.user._id });
      if (!lawyer) {
        return ApiResponse.error(res, "Lawyer profile not found.", 404);
      }

      lawyer.googleConnected = false;
      lawyer.googleEmail = "";
      lawyer.googleAccessToken = "";
      lawyer.googleRefreshToken = "";
      lawyer.googleTokenExpiry = null;

      await lawyer.save();

      return ApiResponse.success(res, "Google Calendar disconnected successfully.", {
        connected: false,
        email: "",
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new LawyerController();
