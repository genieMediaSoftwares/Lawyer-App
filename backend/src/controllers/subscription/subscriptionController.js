const Subscription = require("../../models/Subscription");
const Lawyer = require("../../models/Lawyer");
const ApiResponse = require("../../config/ApiResponse");

class SubscriptionController {
  async getSubscription(req, res, next) {
    try {
      const userId = req.user._id;
      let subscription = await Subscription.findOne({ user: userId, status: "active" })
        .sort({ endDate: -1 });

      if (!subscription) {
        // Fallback or default free plan
        return ApiResponse.success(res, "Active subscription retrieved.", {
          plan: "Free",
          status: "active",
          startDate: new Date(),
          endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days mock
        });
      }

      return ApiResponse.success(res, "Active subscription retrieved.", subscription);
    } catch (error) {
      next(error);
    }
  }

  async subscribe(req, res, next) {
    try {
      const { plan } = req.body;
      const userId = req.user._id;

      if (!plan || !["Free", "Basic", "Premium", "Pro Hub"].includes(plan)) {
        return ApiResponse.error(res, "Invalid or missing plan name.", 400);
      }

      // Expire previous subscriptions
      await Subscription.updateMany({ user: userId, status: "active" }, { status: "expired" });

      const startDate = new Date();
      const endDate = new Date();
      endDate.setFullYear(startDate.getFullYear() + 1); // 1 year plan

      const subscription = await Subscription.create({
        user: userId,
        plan,
        status: "active",
        startDate,
        endDate
      });

      // Update lawyer profile plan
      await Lawyer.findOneAndUpdate(
        { user: userId },
        { subscriptionPlan: plan },
        { new: true }
      );

      return ApiResponse.success(res, "Subscribed successfully.", subscription, 201);
    } catch (error) {
      next(error);
    }
  }

  async cancelSubscription(req, res, next) {
    try {
      const userId = req.user._id;
      const subscription = await Subscription.findOneAndUpdate(
        { user: userId, status: "active" },
        { status: "cancelled" },
        { new: true }
      );

      if (!subscription) {
        return ApiResponse.error(res, "No active subscription found to cancel.", 404);
      }

      await Lawyer.findOneAndUpdate(
        { user: userId },
        { subscriptionPlan: "Free" }
      );

      return ApiResponse.success(res, "Subscription cancelled successfully.", subscription);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new SubscriptionController();
