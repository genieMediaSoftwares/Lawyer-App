const mongoose = require("mongoose");

/**
 * Connecting to the database no longer writes to it.
 *
 * The admin seeder used to run here on every boot, which meant a server
 * restart silently created (and previously reset) an account. Seeding is a
 * deliberate, one-off setup action, so it now lives behind an explicit
 * command: `npm run seed:admin`.
 */

const connectDB = async () => {
  try {
    let mongoUri = (process.env.MONGO_URI || process.env.MONGODB_URI || "").trim();
    // if (!mongoUri.startsWith("mongodb://") && !mongoUri.startsWith("mongodb+srv://")) {
    //   console.warn(
    //     "⚠️ Warning: MONGO_URI in .env is missing or invalid. Falling back to local MongoDB mongodb://127.0.0.1:27017/lawyer_db"
    //   );
    //   mongoUri = "mongodb://127.0.0.1:27017/lawyer_db";
    // }

    const conn = await mongoose.connect(mongoUri);

    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error("❌ MongoDB Connection Failed");
    console.error(error.message);
    process.exit(1);
  }
};

module.exports = connectDB;