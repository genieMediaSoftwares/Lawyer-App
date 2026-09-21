const mongoose = require("mongoose");

const connectDB = async () => {
  try {
    let mongoUri = (process.env.MONGO_URI || process.env.MONGODB_URI || "").trim();

    const conn = await mongoose.connect(mongoUri);

    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error("❌ MongoDB Connection Failed");
    console.error(error.message);
    process.exit(1);
  }
};

module.exports = connectDB;