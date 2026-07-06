const Lawyer = require("../../models/Lawyer");
const User = require("../../models/User");
const ApiResponse = require("../../config/ApiResponse");

class LawyerController {
  async getAllLawyers(req, res, next) {
    try {
      const { search, specialization } = req.query;
      let userQuery = { role: "lawyer" };

      if (search) {
        userQuery.fullName = { $regex: search, $options: "i" };
      }

      const matchingUsers = await User.find(userQuery).select("_id");
      const userIds = matchingUsers.map((u) => u._id);

      let lawyerQuery = { user: { $in: userIds } };
      if (specialization) {
        lawyerQuery.specialization = { $regex: specialization, $options: "i" };
      }

      const lawyers = await Lawyer.find(lawyerQuery).populate(
        "user",
        "fullName email mobile profileImage location"
      );

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
