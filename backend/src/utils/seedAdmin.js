const crypto = require("crypto");
const User = require("../models/User");

const seedAdminAccount = async () => {
  try {
    const adminEmail = process.env.ADMIN_EMAIL || "admin@lawconnect.com";
    const existingAdmin = await User.findOne({ email: adminEmail });

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
