const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const cookieParser = require("cookie-parser");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");
const fileAuthMiddleware = require("./middleware/fileAuthMiddleware");

const errorMiddleware = require("./middleware/errorMiddleware");
const notFoundMiddleware = require("./middleware/notFoundMiddleware");
const authRoutes = require("./routes/authRoutes");
const caseRoutes = require("./routes/case.routes");
const appointmentRoutes = require("./routes/appointment.routes");
const chatRoutes = require("./routes/chat.routes");
const lawyerRoutes = require("./routes/lawyer.routes");
const issueRoutes = require("./routes/issues.routes");
const documentRoutes = require("./routes/document.routes");
const notificationRoutes = require("./routes/notification.routes");
const favoriteRoutes = require("./routes/favorite.routes");
const faqRoutes = require("./routes/faq.routes");
const clientRoutes = require("./routes/client.routes");
const reviewRoutes = require("./routes/review.routes");
const paymentRoutes = require("./routes/payment.routes");
const subscriptionRoutes = require("./routes/subscription.routes");
const courtRoutes = require("./routes/court.routes");
const placeRoutes = require("./routes/place.routes");
const aiRoutes = require("./routes/ai.routes");
const adminRoutes = require("./routes/admin.routes");


const app = express();

const trustProxyHops = Number.parseInt(process.env.TRUST_PROXY ?? "", 10);

if (Number.isInteger(trustProxyHops) && trustProxyHops > 0) {
  app.set("trust proxy", trustProxyHops);
} else if (!Number.isNaN(trustProxyHops) && trustProxyHops === 0) {
  app.set("trust proxy", false);
} else {
  const inferred = process.env.NODE_ENV === "production";
  app.set("trust proxy", inferred ? 1 : false);

  if (!inferred) {
    console.warn(
      "[startup] TRUST_PROXY is not set and NODE_ENV is not production — " +
        "Express will not trust X-Forwarded-For. If this server sits behind " +
        "nginx or a load balancer, set TRUST_PROXY=1 (or 2 behind an ALB), " +
        "or rate limiting will treat all traffic as a single client."
    );
  }
}

app.use(
  helmet({
    crossOriginResourcePolicy: false,
  })
);

const allowedOrigins = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (
        process.env.NODE_ENV !== "production" ||
        allowedOrigins.includes("*") ||
        allowedOrigins.includes(origin)
      ) {
        return callback(null, true);
      }
      return callback(null, false);
    },
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Request-Id",
      "Accept",
      "X-Requested-With",
      "Origin",
      "contentType",
      "responseType",
      "Access-Control-Allow-Headers",
      "Access-Control-Request-Headers",
    ],
    credentials: true,
  })
);

const authLimiter = (max, windowMinutes, options = {}) =>
  rateLimit({
    windowMs: windowMinutes * 60 * 1000,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      message: "Too many attempts. Please try again later.",
      code: "RATE_LIMITED",
    },
    ...options,
  });

app.use(
  "/api/auth/login",
  authLimiter(60, 15, {
    skipSuccessfulRequests: true,
  })
);
app.use("/api/auth/signup", authLimiter(20, 60));
app.use("/api/auth/forgot-password", authLimiter(10, 15));
app.use("/api/auth/reset-password", authLimiter(10, 15));

app.use(
  "/api",
  authLimiter(3000, 15, {
    skip: (req) => req.path.startsWith("/auth/"),
  })
);

app.use(compression());

app.use(
  express.json({
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  })
);
app.use(express.urlencoded({ extended: true }));

app.use(cookieParser());

app.use(morgan(process.env.NODE_ENV === "production" ? "combined" : "dev"));

app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "🚀 Lawyer Consultation Backend Running Successfully",
    version: "1.0.0",
    environment: process.env.NODE_ENV,
  });
});

app.get("/api", (req, res) => {
  res.status(200).json({
    success: true,
    message: "🚀 Lawyer Consultation API Running Successfully",
  });
});

const path = require("path");
app.use(
  "/uploads",
  fileAuthMiddleware,
  express.static(path.join(__dirname, "../uploads"), {
    setHeaders: (res) => {
      res.setHeader("X-Content-Type-Options", "nosniff");
      res.setHeader("Content-Security-Policy", "default-src 'none'");
    },
    index: false,
    dotfiles: "deny",
  })
);

app.use("/api/auth", authRoutes);
app.use("/api/cases", caseRoutes);
app.use("/api/appointments", appointmentRoutes);
app.use("/api/chats", chatRoutes);
app.use("/api/lawyers", lawyerRoutes);
app.use("/api/issues", issueRoutes);
app.use("/api/documents", documentRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/favorites", favoriteRoutes);
app.use("/api/faqs", faqRoutes);
app.use("/api/clients", clientRoutes);
app.use("/api/client", clientRoutes);
app.use("/api/reviews", reviewRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/subscriptions", subscriptionRoutes);
app.use("/api/courts", courtRoutes);
app.use("/api/places", placeRoutes);
app.use("/api/ai", aiRoutes);
app.use("/api/admin", adminRoutes);

app.use(notFoundMiddleware);

app.use(errorMiddleware);

module.exports = app;