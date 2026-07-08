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
}

module.exports = new LawyerController();
