const Subscription = require("../../models/Subscription");
const Lawyer = require("../../models/Lawyer");
const Payment = require("../../models/Payment");
const ApiResponse = require("../../config/ApiResponse");
const razorpayService = require("../../services/payment/razorpayService");

// Exact Lawfly Subscription Catalog Pricing (30 days duration)
const SUBSCRIPTION_CATALOG = {
  Free: 0,
  Starter: 999,
  Professional: 2999,
  Premium: 5999,
  Elite: 12999,
};

class SubscriptionController {
  async getSubscription(req, res, next) {
    try {
      const userId = req.user._id;
      let subscription = await Subscription.findOne({ user: userId, status: "active" })
        .sort({ endDate: -1 });

      if (!subscription) {
        return ApiResponse.success(res, "Active subscription retrieved.", {
          plan: "Free",
          status: "active",
          startDate: new Date(),
          endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        });
      }

      return ApiResponse.success(res, "Active subscription retrieved.", subscription);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Server-authoritative Order Creation for Lawyer Subscription Purchase
   */
  async createSubscriptionOrder(req, res, next) {
    try {
      const { plan } = req.body;
      const userId = req.user._id;

      // Authorization Check: Only registered Lawyers can purchase subscription plans
      const isLawyer = req.user.role === "lawyer" || (await Lawyer.exists({ user: userId }));
      if (!isLawyer) {
        return ApiResponse.error(res, "Only registered lawyers can purchase subscription plans.", 403);
      }

      // Catalog Validation: Only exact catalog plans allowed (Free, Starter, Professional, Premium, Elite)
      if (!plan || SUBSCRIPTION_CATALOG[plan] === undefined) {
        return ApiResponse.error(
          res,
          "Invalid subscription plan. Allowed catalog plans: Free, Starter, Professional, Premium, Elite.",
          400
        );
      }

      const authoritativeAmount = SUBSCRIPTION_CATALOG[plan];

      // Handle Free Plan directly without Razorpay order
      if (authoritativeAmount === 0) {
        await Subscription.updateMany({ user: userId, status: "active" }, { status: "expired" });

        const startDate = new Date();
        const endDate = new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000);

        const subscription = await Subscription.create({
          user: userId,
          plan: "Free",
          status: "active",
          startDate,
          endDate,
        });

        await Lawyer.findOneAndUpdate(
          { user: userId },
          { subscriptionPlan: "Free" }
        );

        return ApiResponse.success(res, "Free plan activated successfully.", {
          isFree: true,
          subscription,
        });
      }

      // Create Razorpay Order server-side for paid subscription
      const receipt = `sub_${userId}_${Date.now()}`;
      const order = await razorpayService.createOrder({
        amount: authoritativeAmount,
        currency: "INR",
        receipt,
        notes: {
          lawyerId: userId.toString(),
          purpose: "subscription",
          subscriptionPlan: plan,
        },
      });

      // Create pending Payment record (Subscription ownership belongs to authenticated Lawyer)
      const payment = await Payment.create({
        client: userId, // Authenticated Lawyer purchasing subscription
        lawyer: userId, // Authenticated Lawyer
        amount: authoritativeAmount,
        currency: "INR",
        purpose: "subscription",
        subscriptionPlan: plan,
        status: "pending",
        razorpayOrderId: order.id,
        paymentMethod: "Razorpay",
      });

      return ApiResponse.success(
        res,
        "Subscription order created successfully.",
        {
          orderId: order.id,
          amount: authoritativeAmount,
          currency: "INR",
          keyId: razorpayService.keyId || "",
          paymentId: payment._id,
          plan,
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

      if (!plan || SUBSCRIPTION_CATALOG[plan] === undefined) {
        return ApiResponse.error(res, "Invalid or missing plan name.", 400);
      }

      // Live mode protection
      if (process.env.PAYMENT_MODE === "live" && SUBSCRIPTION_CATALOG[plan] > 0) {
        return ApiResponse.error(
          res,
          "LIVE MODE PROTECTION: Paid subscription requires server order creation and payment verification via /api/subscriptions/create-order.",
          400
        );
      }

      await Subscription.updateMany({ user: userId, status: "active" }, { status: "expired" });

      const startDate = new Date();
      const endDate = new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000);

      const subscription = await Subscription.create({
        user: userId,
        plan,
        status: "active",
        startDate,
        endDate,
      });

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
