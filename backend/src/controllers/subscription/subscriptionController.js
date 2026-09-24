const Subscription = require("../../models/Subscription");
const Lawyer = require("../../models/Lawyer");
const Payment = require("../../models/Payment");
const ApiResponse = require("../../config/ApiResponse");
const notificationService = require("../../services/notification/notificationService");

const PLAN_DURATIONS_DAYS = {
  Free: 30,
  Starter: 30,
  Professional: 30,
  Premium: 30,
  Elite: 30,
};

class SubscriptionController {
  async getSubscription(req, res, next) {
    try {
      const userId = req.user._id;
      let subscription = await Subscription.findOne({ user: userId, status: "active" }).sort({ endDate: -1 });

      if (!subscription) {
        return ApiResponse.success(res, "Active subscription retrieved.", {
          plan: "Free",
          status: "active",
          startDate: new Date(),
          endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        });
      }

      return ApiResponse.success(res, "Active subscription retrieved.", subscription);
    } catch (error) {
      next(error);
    }
  }

  async createSubscriptionOrder(req, res, next) {
    try {
      const { plan } = req.body;
      const userId = req.user._id;

      const isLawyer = req.user.role === "lawyer" || (await Lawyer.exists({ user: userId }));
      if (!isLawyer) {
        return ApiResponse.error(res, "Only registered lawyers can purchase subscription plans.", 403);
      }

      if (!plan || PLAN_DURATIONS_DAYS[plan] === undefined) {
        return ApiResponse.error(
          res,
          "Invalid subscription plan. Allowed plans: Free, Starter, Professional, Premium, Elite.",
          400
        );
      }

      await Subscription.updateMany({ user: userId, status: "active" }, { status: "expired" });

      const startDate = new Date();
      const durationDays = PLAN_DURATIONS_DAYS[plan];
      const endDate = new Date(startDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

      const subscription = await Subscription.create({
        user: userId,
        plan,
        status: "active",
        startDate,
        endDate,
      });

      await Lawyer.findOneAndUpdate({ user: userId }, { subscriptionPlan: plan });

      notificationService
        .createAndSendNotification({
          receiverId: userId,
          type: "subscription_success",
          title: "Subscription Activated",
          message: `Your ${plan} subscription is now active (Free Plan tier).`,
          referenceId: subscription._id.toString(),
        })
        .catch(() => {});

      return ApiResponse.success(
        res,
        "Subscription activated successfully.",
        {
          isFree: true,
          orderId: subscription._id.toString(),
          paymentId: subscription._id,
          subscription,
          plan,
          amount: 0,
          currency: "INR",
          status: "completed",
        },
        201
      );
    } catch (error) {
      next(error);
    }
  }

  async subscribe(req, res, next) {
    try {
      const { plan } = req.body;
      const userId = req.user._id;

      if (!plan || PLAN_DURATIONS_DAYS[plan] === undefined) {
        return ApiResponse.error(res, "Invalid or missing plan name.", 400);
      }

      await Subscription.updateMany({ user: userId, status: "active" }, { status: "expired" });

      const startDate = new Date();
      const endDate = new Date(startDate.getTime() + PLAN_DURATIONS_DAYS[plan] * 24 * 60 * 60 * 1000);

      const subscription = await Subscription.create({
        user: userId,
        plan,
        status: "active",
        startDate,
        endDate,
      });

      await Lawyer.findOneAndUpdate({ user: userId }, { subscriptionPlan: plan }, { new: true });

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

      await Lawyer.findOneAndUpdate({ user: userId }, { subscriptionPlan: "Free" });

      return ApiResponse.success(res, "Subscription cancelled successfully.", subscription);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new SubscriptionController();
