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

        // Generate responseTime pseudo-randomly but stably based on name length
        const nameLen = lawyer.user.fullName.length;
        const responseTimeMins = 10 + (nameLen % 4) * 5; // 10, 15, 20, 25 mins
        const responseTime = `Responds in ${responseTimeMins} mins`;

        // Extract city/district/state from location string (e.g. "Visakhapatnam, Andhra Pradesh")
        const locParts = lawyer.user.location.split(",");
        const parsedCity = locParts[0] ? locParts[0].trim() : "Unknown";
        const parsedState = locParts[1] ? locParts[1].trim() : "India";

        // Practice areas / tags
        const practiceAreas = [
          lawyer.specialization,
          subcategory || "Legal Advice",
          category || "General Advice"
        ].filter((v, i, self) => self.indexOf(v) === i); // unique

        return {
          lawyerId: lawyer._id, // lawyer document ID
          userId: lawyer.user._id, // user document ID
          profileImage: lawyer.user.profileImage || "",
          fullName: lawyer.user.fullName,
          specialization: lawyer.specialization,
          city: parsedCity,
          district: district || parsedCity,
          state: parsedState,
          experience: lawyer.experience,
          rating: lawyer.rating,
          reviewCount: lawyer.totalReviews,
          consultationFee: lawyer.consultationFee,
          languages: lawyer.languages || ["English", "Hindi"],
          practiceAreas: practiceAreas,
          verified: lawyer.user.isVerified,
          onlineStatus: lawyer.user.isActive,
          responseTime: responseTime,
          matchPercentage: matchPercentage,
          casesHandled: lawyer.casesHandled || 120,
          locationScore: locationScore, // helper for sorting
          winPercentage: lawyer.winPercentage || 85,
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
}

module.exports = new LawyerController();
