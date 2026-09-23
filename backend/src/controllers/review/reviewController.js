const Review = require("../../models/Review");
const notificationService = require("../../services/notification/notificationService");
const Lawyer = require("../../models/Lawyer");
const Case = require("../../models/Case");
const Appointment = require("../../models/Appointment");
const ApiResponse = require("../../config/ApiResponse");

class ReviewController {
  async createReview(req, res, next) {
    try {
      const { lawyerId, rating, review } = req.body;
      const client = req.user._id;

      if (!lawyerId || !rating || !review) {
        return ApiResponse.error(res, "Lawyer ID, rating, and review text are required.", 400);
      }

      const ratingValue = Number(rating);
      if (!Number.isFinite(ratingValue) || ratingValue < 1 || ratingValue > 5) {
        return ApiResponse.error(res, "Rating must be between 1 and 5.", 400);
      }

      // Only a client who actually worked with this lawyer may review them:
      // a case assigned to them, or a booked appointment. Without this any
      // signed-in user could review any lawyer and move their rating.
      const [workedTogether, hadAppointment] = await Promise.all([
        Case.exists({ client, assignedLawyer: lawyerId }),
        Appointment.exists({ client, lawyer: lawyerId }),
      ]);

      if (!workedTogether && !hadAppointment) {
        return ApiResponse.error(
          res,
          "You can review an advocate only after a consultation or case with them.",
          403
        );
      }

      // One review per advocate per client, so a rating cannot be stacked.
      const existing = await Review.findOne({ lawyer: lawyerId, client });
      if (existing) {
        return ApiResponse.error(
          res,
          "You have already reviewed this advocate.",
          409
        );
      }

      const newReview = await Review.create({
        lawyer: lawyerId,
        client,
        rating: ratingValue,
        review,
      });

      const reviews = await Review.find({ lawyer: lawyerId });
      const totalReviews = reviews.length;
      const avgRating = reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews;

      await Lawyer.findOneAndUpdate(
        { user: lawyerId },
        { rating: parseFloat(avgRating.toFixed(1)), totalReviews },
        { new: true }
      );

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
      } else {
        // A client asking without a lawyerId gets their own reviews, not every
        // review on the platform (which exposed other clients' names and text).
        query.client = req.user._id;
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

      if (reviewItem.lawyer.toString() !== lawyerId.toString()) {
        return ApiResponse.error(res, "Unauthorized to reply to this review.", 403);
      }

      reviewItem.reply = reply;
      reviewItem.replyDate = new Date();
      await reviewItem.save();

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
