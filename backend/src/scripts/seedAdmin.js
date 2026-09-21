require("dotenv").config();
const connectDB = require("../config/db");
const seedAdminAccount = require("../utils/seedAdmin");
const mongoose = require("mongoose");

const runSeed = async () => {
  try {
    await connectDB();
    await seedAdminAccount();
    console.log("Admin seeding completed.");
    process.exit(0);
  } catch (error) {
    console.error("Failed to run seed script:", error);
    process.exit(1);
  }
};

runSeed();
