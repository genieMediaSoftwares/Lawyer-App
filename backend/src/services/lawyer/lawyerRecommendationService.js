const Lawyer = require("../../models/Lawyer");

class LawyerRecommendationService {
  async getRecommendations({ category, subcategory, city, district, state, sortBy, limit = 10 }) {
    if (!category) {
      throw new Error("Category is required for recommendation.");
    }

    const catPattern = category.trim();
    const subPattern = (subcategory || "").trim();

    const allLawyers = await Lawyer.find()
      .populate("user", "fullName email mobile profileImage location isVerified isActive")
      .exec();

    const activeLawyers = allLawyers.filter((l) => l.user != null);

    const scored = activeLawyers.map((lawyer) => {
      const user = lawyer.user;
      const userLoc = (user.location || "").toLowerCase();
      const spec = (lawyer.specialization || "").toLowerCase();
      const cat = catPattern.toLowerCase();
      const sub = subPattern.toLowerCase();

      let locationScore = 0;
      if (city && userLoc.includes(city.toLowerCase())) {
        locationScore = 35;
      } else if (district && userLoc.includes(district.toLowerCase())) {
        locationScore = 25;
      } else if (state && userLoc.includes(state.toLowerCase())) {
        locationScore = 15;
      }

      let specScore = 0;
      if (spec.includes(cat) || cat.includes(spec)) {
        specScore += 20;
      }
      if (sub && (spec.includes(sub) || sub.includes(spec))) {
        specScore += 10;
      }
      if (spec.includes("general") || spec.includes("litigation")) {
        specScore += 10;
      }

      const ratingScore = ((lawyer.rating || 4.0) / 5.0) * 15;

      const expScore = Math.min(10, ((lawyer.experience || 1) / 10) * 10);

      const verifiedScore = user.isVerified ? 10 : 0;

      const rawTotal = 40 + locationScore * 0.4 + specScore * 0.6 + ratingScore + expScore + verifiedScore * 0.5;
      const matchPercentage = Math.min(98, Math.max(65, Math.round(rawTotal)));

      const locParts = (user.location || "").split(",");
      const parsedCity = locParts[0] ? locParts[0].trim() : "";
      const parsedState = locParts[1] ? locParts[1].trim() : "";

      const practiceAreas = (
        Array.isArray(lawyer.practiceAreas) && lawyer.practiceAreas.length
          ? lawyer.practiceAreas
          : [lawyer.specialization]
      ).filter(Boolean);

      return {
        lawyerId: lawyer._id,
        userId: user._id,
        profileImage: user.profileImage || "",
        fullName: user.fullName,
        specialization: lawyer.specialization,
        city: parsedCity,
        district: lawyer.district || parsedCity,
        state: parsedState,
        location: user.location || "",
        experience: lawyer.experience,
        rating: lawyer.rating,
        reviewCount: lawyer.totalReviews,
        consultationFee: lawyer.consultationFee,
        languages: lawyer.languages?.length ? lawyer.languages : ["English", "Hindi"],
        practiceAreas: practiceAreas,
        verified: user.isVerified,
        onlineStatus: user.isActive,
        responseTime: lawyer.responseTime || "Responds within 2 hours",
        matchPercentage,
        casesHandled: typeof lawyer.casesHandled === "number" ? lawyer.casesHandled : 120,
        winPercentage: typeof lawyer.winPercentage === "number" ? lawyer.winPercentage : 85,
        locationScore,
        bio: lawyer.bio || "",
        education: lawyer.education || "",
        barCouncilNumber: lawyer.barCouncilNumber || "",
        officeAddress: lawyer.officeAddress || "",
        workingHours: lawyer.workingHours || "9:00 AM - 6:00 PM",
      };
    });

    const filtered = scored.filter((l) => {
      const spec = l.specialization.toLowerCase();
      const cat = catPattern.toLowerCase();
      const sub = subPattern.toLowerCase();
      return (
        spec.includes(cat) ||
        cat.includes(spec) ||
        spec.includes("general") ||
        spec.includes("litigation") ||
        (sub && (spec.includes(sub) || sub.includes(spec)))
      );
    });

    filtered.sort((a, b) => {
      if (sortBy === "Best Match") {
        return b.matchPercentage - a.matchPercentage;
      } else if (sortBy === "Experience") {
        return b.experience - a.experience;
      } else if (sortBy === "Rating") {
        return b.rating - a.rating;
      } else if (sortBy === "Fees: Low to High") {
        return a.consultationFee - b.consultationFee;
      }
      return b.matchPercentage - a.matchPercentage;
    });

    return filtered.slice(0, limit);
  }
}

module.exports = new LawyerRecommendationService();
