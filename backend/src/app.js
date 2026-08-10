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

// Behind nginx or an ALB — the normal EC2 arrangement — every request arrives
// from the proxy, so req.ip is the proxy's address unless Express is told to
// read X-Forwarded-For. Without this the rate limiters below count the entire
// user base as one client and the global 300/15min ceiling is reached by
// ordinary traffic, locking everyone out.
//
// Set to 1 (a single trusted hop) rather than `true`, which would trust a
// client-supplied X-Forwarded-For and let anyone spoof their way past the
// limiter. Increase it only if you add another proxy in front.
if (process.env.NODE_ENV === "production") {
  app.set("trust proxy", 1);
}

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
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (
        process.env.NODE_ENV !== "production" ||
        allowedOrigins.length === 0 ||
        allowedOrigins.includes("*") ||
        allowedOrigins.includes(origin) ||
        origin.includes("localhost") ||
        origin.includes("127.0.0.1") ||
        origin.includes("duckdns.org")
      ) {
        return callback(null, true);
      }
      return callback(null, true);
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

// Rate limiting.
//
// These ceilings were low enough that ordinary use hit them, and every one of
// them answers with the same "Too many attempts" body — which is how a wrong
// password, a duplicate signup and a second-device login all ended up wearing
// that message. Two things caused it:
//
//   * Login allowed 5 requests per 15 minutes and counted *successful* ones
//     too, so five sign-ins across a household or an office — everyone behind
//     one NAT address, one key as far as the limiter is concerned — locked the
//     endpoint for everybody.
//   * The catch-all `/api` limiter allowed 300 per 15 minutes for that same
//     shared key. This app opens sockets, polls chats and loads dashboards;
//     normal traffic exhausts it, and once it does *every* endpoint answers
//     429 — including login, which then blames the user for too many login
//     attempts they never made.
//
// The limits below are abuse ceilings, not attempt counters: high enough that
// no legitimate user reaches them, low enough to stop credential stuffing and
// brute-forcing a 6-digit reset code. Login additionally stops counting
// requests that succeed, so a working sign-in never brings a user closer to
// being blocked.
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
    // Only failures count. Somebody signing in normally — including retrying
    // after a genuine typo, or reconnecting from a shared network — is not
    // spending budget.
    skipSuccessfulRequests: true,
  })
);
app.use("/api/auth/signup", authLimiter(20, 60));
app.use("/api/auth/forgot-password", authLimiter(10, 15));
// The reset code is six digits, so this window is the thing standing between
// an attacker and 1-in-a-million guesses. Kept genuinely tight.
app.use("/api/auth/reset-password", authLimiter(10, 15));

// Catch-all ceiling for everything else. Auth is excluded because it is
// covered above, and because a user who has been browsing must never be told
// they cannot sign in.
app.use(
  "/api",
  authLimiter(3000, 15, {
    skip: (req) => req.path.startsWith("/auth/"),
  })
);

// Compression
app.use(compression());

// Body Parser
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Cookies
app.use(cookieParser());

// Logger. "dev" is colourised and unbuffered — fine at a terminal, wasteful in
// a journal. Production gets the standard combined format, which is what log
// shippers expect.
app.use(morgan(process.env.NODE_ENV === "production" ? "combined" : "dev"));

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