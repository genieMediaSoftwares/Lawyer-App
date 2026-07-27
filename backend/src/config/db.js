const mongoose = require("mongoose");
const seedAdminAccount = require("../utils/seedAdmin");

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI);

    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
    await seedAdminAccount();
  } catch (error) {
    console.error("❌ MongoDB Connection Failed");
    console.error(error.message);
    process.exit(1);
  }
};

module.exports = connectDB;