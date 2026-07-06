const Issue = require("../../models/Issue");
const ApiResponse = require("../../config/ApiResponse");

class IssueController {
  async createIssue(req, res, next) {
    try {
      const { title, description, category, urgency, preferredLanguage, location, preferredMode, documents, images } = req.body;
      const clientId = req.user._id;

      const newIssue = await Issue.create({
        title,
        description,
        category,
        urgency,
        preferredLanguage,
        location,
        preferredMode,
        documents: documents || [],
        images: images || [],
        clientId,
        status: "Pending"
      });

      return ApiResponse.success(res, "Issue created successfully.", newIssue, 201);
    } catch (error) {
      next(error);
    }
  }

  async getIssues(req, res, next) {
    try {
      let query = {};
      // If client, show only their issues. If lawyer or admin, show all or matching.
      if (req.user.role === "client") {
        query.clientId = req.user._id;
      }

      const issues = await Issue.find(query)
        .populate("clientId", "fullName email mobile profileImage")
        .sort({ createdAt: -1 });

      return ApiResponse.success(res, "Issues fetched successfully.", issues);
    } catch (error) {
      next(error);
    }
  }

  async getIssueById(req, res, next) {
    try {
      const { id } = req.params;
      const issue = await Issue.findById(id).populate("clientId", "fullName email mobile profileImage");
      if (!issue) {
        return ApiResponse.error(res, "Issue not found.", 404);
      }
      return ApiResponse.success(res, "Issue details fetched successfully.", issue);
    } catch (error) {
      next(error);
    }
  }

  async updateIssue(req, res, next) {
    try {
      const { id } = req.params;
      const updates = req.body;

      const issue = await Issue.findByIdAndUpdate(id, updates, { new: true, runValidators: true });
      if (!issue) {
        return ApiResponse.error(res, "Issue not found.", 404);
      }

      return ApiResponse.success(res, "Issue updated successfully.", issue);
    } catch (error) {
      next(error);
    }
  }

  async deleteIssue(req, res, next) {
    try {
      const { id } = req.params;
      const issue = await Issue.findByIdAndDelete(id);
      if (!issue) {
        return ApiResponse.error(res, "Issue not found.", 404);
      }
      return ApiResponse.success(res, "Issue deleted successfully.", null);
    } catch (error) {
      next(error);
    }
  }

  async getIssueStatus(req, res, next) {
    try {
      const { id } = req.params;
      const issue = await Issue.findById(id).select("status title description category");
      if (!issue) {
        return ApiResponse.error(res, "Issue not found.", 404);
      }
      return ApiResponse.success(res, "Issue status fetched.", issue);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new IssueController();
