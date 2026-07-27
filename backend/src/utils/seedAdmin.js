const User = require("../models/User");

/**
 * Seed Default Administrator Account
 * Email: admin@lawconnect.com
 * Password: Admin123@ (Hashed via User pre-save bcrypt hook)
 * Role: admin
 */
const seedAdminAccount = async () => {
  try {
    const adminEmail = "admin@lawconnect.com";
    const existingAdmin = await User.findOne({ email: adminEmail }).select("+password");

    if (existingAdmin) {
      existingAdmin.password = "Admin123@";
      existingAdmin.role = "admin";
      existingAdmin.isVerified = true;
      existingAdmin.isActive = true;
      await existingAdmin.save();
      console.log(`Default Admin Account (${adminEmail}) updated/reset to password: Admin123@`);
      return existingAdmin;
    }

    const newAdmin = new User({
      fullName: "System Administrator",
      email: adminEmail,
      mobile: "+10000000000",
      password: "Admin123@",
      role: "admin",
      isVerified: true,
      isActive: true,
    });

    await newAdmin.save();
    console.log(`
=========================================
🛡️ Default Admin Account Created Successfully!
📧 Email    : admin@lawconnect.com
🔑 Password : Admin123@
🏷️ Role     : admin
=========================================
    `);
    return newAdmin;
  } catch (error) {
    console.error("Error seeding default admin account:", error.message);
  }
};

module.exports = seedAdminAccount;
