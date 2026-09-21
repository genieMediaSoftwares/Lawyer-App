const crypto = require("crypto");
const User = require("../models/User");

/**
 * Seed the default administrator account.
 *
 * Runs on every database connection (see config/db.js), so it must be
 * idempotent and must never touch an admin account that already exists.
 *
 * It previously reset the existing admin's password to a hardcoded
 * "Admin123@" on every boot and printed it to stdout — which meant the
 * credentials were public knowledge from the source, any password the admin
 * chose was silently reverted at the next restart, and the value leaked into
 * server logs.
 *
 * Credentials now come from ADMIN_EMAIL / ADMIN_PASSWORD. In production both
 * are required; nothing is seeded without them. In development a random
 * password is generated and printed once, on first creation only.
 */
const seedAdminAccount = async () => {
  try {
    const adminEmail = process.env.ADMIN_EMAIL || "admin@lawconnect.com";
    const existingAdmin = await User.findOne({ email: adminEmail });

    // Never reset the password, role or status of an account that exists.
    if (existingAdmin) {
      return existingAdmin;
    }

    let password = process.env.ADMIN_PASSWORD;

    if (!password) {
      if (process.env.NODE_ENV === "production") {
        console.warn(
          "⚠️  ADMIN_PASSWORD is not set — skipping admin seed. " +
            "Set ADMIN_EMAIL and ADMIN_PASSWORD to create the initial admin."
        );
        return null;
      }
      // Development convenience: a random password, shown once.
      password = crypto.randomBytes(12).toString("base64url");
    }

    const newAdmin = new User({
      fullName: "System Administrator",
      email: adminEmail,
      mobile: process.env.ADMIN_MOBILE || "+10000000000",
      password,
      role: "admin",
      isVerified: true,
      isActive: true,
    });

    await newAdmin.save();

    console.log(`
=========================================
🛡️ Default Admin Account Created
📧 Email : ${adminEmail}
🔑 Password : ${
      process.env.ADMIN_PASSWORD
        ? "(from ADMIN_PASSWORD)"
        : `${password}   <-- shown once, change it after first sign-in`
    }
=========================================
    `);
    return newAdmin;
  } catch (error) {
    console.error("Error seeding default admin account:", error.message);
  }
};

module.exports = seedAdminAccount;
