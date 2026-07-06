const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const cookieParser = require("cookie-parser");
const morgan = require("morgan");
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

const app = express();

// Security
app.use(helmet());

// CORS
app.use(cors());

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

// Serve local uploads folder statically
app.use("/uploads", express.static("uploads"));

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
app.use("/api/reviews", reviewRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/subscriptions", subscriptionRoutes);

// Global Error Handler
app.use(errorMiddleware);

module.exports = app;