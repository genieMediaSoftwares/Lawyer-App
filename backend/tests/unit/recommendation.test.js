const lawyerRecommendationService = require("../../src/services/lawyer/lawyerRecommendationService");

describe("Lawyer Recommendation Service Unit Tests", () => {
  it("should throw error if category is missing", async () => {
    await expect(lawyerRecommendationService.getRecommendations({})).rejects.toThrow(
      "Category is required for recommendation."
    );
  });
});
