const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const cookieParser = require("cookie-parser");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");
const fileAuthMiddleware = require("./middleware/fileAuthMiddleware");

const errorMiddleware = require("./middleware/errorMiddleware");
const authRoutes = require("./routes/authRoutes");
const caseRoutes = require("./routes/case.routes");
const appointmentRoutes = require("./routes/appointment.routes");
const chatRoutes = require("./routes/chat.routes");
const lawyerRoutes = require("./routes/lawyer.routes");
const issueRoutes = require("./routes/issues.routes");
const documentRoutes = require("./routes/document.routes");
const notificationRoutes = require("./routes/notification.routes");
const favoriteRoutes = require("./routes/favorite.routes");
const articleRoutes = require("./routes/article.routes");
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

// Security
app.use(
  helmet({
    crossOriginResourcePolicy: false,
  })
);

// CORS – unrestricted in development, allowlisted in production.
// ALLOWED_ORIGINS is a comma-separated list, e.g. "https://app.genielaw.in".
const allowedOrigins = (process.env.ALLOWED_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(
  cors({
    origin:
      process.env.NODE_ENV === "production" ? allowedOrigins : "*",
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// Rate limiting. Without this, the login endpoint is open to credential
// stuffing and the password-reset code is brute-forceable within its window.
const authLimiter = (max, windowMinutes) =>
  rateLimit({
    windowMs: windowMinutes * 60 * 1000,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      message: "Too many attempts. Please try again later.",
    },
  });

app.use("/api/auth/login", authLimiter(5, 15));
app.use("/api/auth/signup", authLimiter(3, 60));
app.use("/api/auth/forgot-password", authLimiter(3, 15));
app.use("/api/auth/reset-password", authLimiter(5, 15));
app.use("/api", authLimiter(300, 15));

// Compression
app.use(compression());

// Body Parser
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Cookies
app.use(cookieParser());

// Logger
app.use(morgan("dev"));

// Health Check
app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "🚀 Lawyer Consultation Backend Running Successfully",
    version: "1.0.0",
    environment: process.env.NODE_ENV,
  });
});

// API Root Health Check
app.get("/api", (req, res) => {
  res.status(200).json({
    success: true,
    message: "🚀 Lawyer Consultation API Running Successfully",
  });
});

const path = require("path");
// Uploaded files. fileAuthMiddleware lets /uploads/profiles through (public
// avatars) and authorises every other folder per request — case evidence,
// voice recordings and acknowledgement documents were previously downloadable
// by anyone holding the URL.
//
// express.static is kept behind the guard rather than replaced by sendFile so
// that Range requests keep working; audio playback seeking depends on them.
app.use(
  "/uploads",
  fileAuthMiddleware,
  express.static(path.join(__dirname, "../uploads"), {
    // Never let an upload be interpreted as active content on our origin.
    setHeaders: (res) => {
      res.setHeader("X-Content-Type-Options", "nosniff");
      res.setHeader("Content-Security-Policy", "default-src 'none'");
    },
    index: false,
    dotfiles: "deny",
  })
);

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/cases", caseRoutes);
app.use("/api/appointments", appointmentRoutes);
app.use("/api/chats", chatRoutes);
app.use("/api/lawyers", lawyerRoutes);
app.use("/api/issues", issueRoutes);
app.use("/api/documents", documentRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/favorites", favoriteRoutes);
app.use("/api/articles", articleRoutes);
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

// Global Error Handler
app.use(errorMiddleware);

module.exports = app;