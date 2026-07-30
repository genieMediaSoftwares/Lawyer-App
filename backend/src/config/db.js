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
    const conn = await mongoose.connect(process.env.MONGO_URI);

    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error("❌ MongoDB Connection Failed");
    console.error(error.message);
    process.exit(1);
  }
};

module.exports = connectDB;