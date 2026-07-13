const Review = require("../../models/Review");
const notificationService = require("../../services/notification/notificationService");
const Lawyer = require("../../models/Lawyer");
const ApiResponse = require("../../config/ApiResponse");

class ReviewController {
  async createReview(req, res, next) {
    try {
      const { lawyerId, rating, review } = req.body;
      const client = req.user._id;

      if (!lawyerId || !rating || !review) {
        return ApiResponse.error(res, "Lawyer ID, rating, and review text are required.", 400);
      }

      const newReview = await Review.create({
        lawyer: lawyerId,
        client,
        rating,
        review,
      });

      // Update lawyer's average rating and total reviews count
      const reviews = await Review.find({ lawyer: lawyerId });
      const totalReviews = reviews.length;
      const avgRating = reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews;

      await Lawyer.findOneAndUpdate(
        { user: lawyerId },
        { rating: parseFloat(avgRating.toFixed(1)), totalReviews },
        { new: true }
      );

      // Notify the lawyer
      await notificationService.createAndSendNotification({
        senderId: client,
        receiverId: lawyerId,
        type: "review_received",
        title: "New Review Received",
        message: `A client left you a ${rating}-star review: "${review.substring(0, 30)}${review.length > 30 ? '...' : ''}"`,
        referenceId: newReview._id.toString()
      });

      return ApiResponse.success(res, "Review submitted successfully.", newReview, 201);
    } catch (error) {
      next(error);
    }
  }

  async getReviews(req, res, next) {
    try {
      const { lawyerId } = req.query;
      let query = { isHidden: false };

      if (lawyerId) {
        query.lawyer = lawyerId;
      } else if (req.user.role === "lawyer") {
        query.lawyer = req.user._id;
      }

      const reviews = await Review.find(query)
        .populate("client", "fullName profileImage")
        .sort({ createdAt: -1 });

      return ApiResponse.success(res, "Reviews fetched successfully.", reviews);
    } catch (error) {
      next(error);
    }
  }

  async replyToReview(req, res, next) {
    try {
      const { id } = req.params;
      const { reply } = req.body;
      const lawyerId = req.user._id;

      const reviewItem = await Review.findById(id);
      if (!reviewItem) {
        return ApiResponse.error(res, "Review not found.", 404);
      }

      // Check authorization
      if (reviewItem.lawyer.toString() !== lawyerId.toString()) {
        return ApiResponse.error(res, "Unauthorized to reply to this review.", 403);
      }

      reviewItem.reply = reply;
      reviewItem.replyDate = new Date();
      await reviewItem.save();

      // Notify the client
      await notificationService.createAndSendNotification({
        senderId: lawyerId,
        receiverId: reviewItem.client,
        type: "review_received",
        title: "Advocate Replied to Your Review",
        message: `An advocate replied to your review: "${reply.substring(0, 30)}${reply.length > 30 ? '...' : ''}"`,
        referenceId: reviewItem._id.toString()
      });

      return ApiResponse.success(res, "Reply added successfully.", reviewItem);
    } catch (error) {
      next(error);
    }
  }

  async hideReview(req, res, next) {
    try {
      const { id } = req.params;

      const reviewItem = await Review.findById(id);
      if (!reviewItem) {
        return ApiResponse.error(res, "Review not found.", 404);
      }

      // Set hidden flag
      reviewItem.isHidden = true;
      await reviewItem.save();

      return ApiResponse.success(res, "Review hidden successfully.", reviewItem);
    } catch (error) {
      next(error);
    }
  }

  async reportReview(req, res, next) {
    try {
      const { id } = req.params;

      const reviewItem = await Review.findById(id);
      if (!reviewItem) {
        return ApiResponse.error(res, "Review not found.", 404);
      }

      reviewItem.isReported = true;
      await reviewItem.save();

      return ApiResponse.success(res, "Review reported successfully.", reviewItem);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ReviewController();
