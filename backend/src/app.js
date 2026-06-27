const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const cookieParser = require("cookie-parser");
const morgan = require("morgan");
const errorMiddleware = require("./middleware/errorMiddleware");
const authRoutes = require("./routes/authRoutes");

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

// Routes
app.use("/api/auth", authRoutes);

// Global Error Handler
app.use(errorMiddleware);

module.exports = app;