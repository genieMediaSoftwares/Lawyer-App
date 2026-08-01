const crypto = require("crypto");

const userRepository = require("../../repositories/userRepository");
const generateToken = require("../../utils/generateToken");
const AppError = require("../../utils/AppError");

// Reset codes are stored hashed, so the lookup in resetPassword has to hash the
// candidate the same way. SHA-256 is appropriate here (unlike for passwords):
// the input is high-entropy and short-lived, and the comparison must be fast.
const hashResetToken = (token) =>
  crypto.createHash("sha256").update(String(token)).digest("hex");


class AuthService {
  /**
   * Register User
   */
  async register(userData) {
    // Check Email
    const emailExists = await userRepository.findByEmail(
      userData.email
    );

    if (emailExists) {
      throw new AppError("Email already registered.", 409);
    }

    // Check Mobile
    const mobileExists = await userRepository.findByMobile(
      userData.mobile
    );

    if (mobileExists) {
      throw new AppError("Mobile number already registered.", 409);
    }

    // Allowlist the fields a self-registering user is permitted to set.
    // Never hand the raw request body to Mongoose: privileged schema fields
    // (isVerified, isActive, role="admin") would otherwise be mass-assignable.
    // `isVerified` in particular is the same flag the admin verification flow
    // sets, so an attacker could self-register as a verified advocate.
    const user = await userRepository.create({
      fullName: userData.fullName,
      email: userData.email,
      mobile: userData.mobile,
      password: userData.password,
      role: userData.role === "lawyer" ? "lawyer" : "client",
    });

    // Generate JWT
    const token = generateToken(user);

    return {
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        mobile: user.mobile,
        role: user.role,
        profileImage: user.profileImage,
        location: user.location || "",
      },
    };
  }

  /**
   * Login User
   */
  async login(email, password) {
    const user = await userRepository.findByEmail(email);

    if (!user) {
      throw new AppError("Invalid email or password.", 401);
    }

    const isPasswordCorrect =
      await user.comparePassword(password);

    if (!isPasswordCorrect) {
      throw new AppError("Invalid email or password.", 401);
    }

    const token = generateToken(user);

    return {
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        mobile: user.mobile,
        role: user.role,
        profileImage: user.profileImage,
        location: user.location || "",
      },
    };
  }

  /**
   * Get Profile
   */
  async getProfile(userId) {
    const user = await userRepository.findById(userId);

    if (!user) {
      throw new AppError("User not found.", 404);
    }

    return user;
  }

  async updateProfile(userId, updateData) {
    const user = await userRepository.update(userId, updateData);
    if (!user) {
      throw new AppError("User not found.", 404);
    }
    return {
      id: user._id,
      fullName: user.fullName,
      email: user.email,
      mobile: user.mobile,
      role: user.role,
      profileImage: user.profileImage,
      location: user.location || "",
    };
  }

  async forgotPassword(email) {
    const User = require("../../models/User");
    const user = await User.findOne({ email });
    // Do not reveal whether the address is registered — an error here would
    // turn this endpoint into a user-enumeration oracle. Always resolve the
    // same way; the caller sends an identical response either way.
    if (!user) {
      return;
    }

    // crypto.randomInt is CSPRNG-backed; Math.random() is predictable.
    const resetToken = crypto.randomInt(100000, 1000000).toString();

    // Store only a hash. A database read must not yield a usable reset code.
    user.resetPasswordToken = hashResetToken(resetToken);
    user.resetPasswordExpire = Date.now() + 15 * 60 * 1000; // 15 minutes
    await user.save();

    if (process.env.NODE_ENV !== "production") {
      console.log(`[dev] Password reset code for ${email}: ${resetToken}`);
    }
  }

  async resetPassword(email, token, newPassword) {
    const User = require("../../models/User");
    const user = await User.findOne({
      email,
      resetPasswordToken: hashResetToken(token),
      resetPasswordExpire: { $gt: Date.now() },
    });

    if (!user) {
      throw new AppError("Invalid or expired reset token.", 400);
    }

    user.password = newPassword;
    user.resetPasswordToken = null;
    user.resetPasswordExpire = null;
    await user.save();

    return true;
  }

  async changePassword(userId, oldPassword, newPassword) {
    const User = require("../../models/User");
    const user = await User.findById(userId).select("+password");
    if (!user) {
      throw new AppError("User not found.", 404);
    }

    const isMatch = await user.comparePassword(oldPassword);
    if (!isMatch) {
      throw new AppError("Incorrect old password.", 400);
    }

    user.password = newPassword;
    await user.save();

    return true;
  }
  async deleteAccount(userId, password) {
    const User = require("../../models/User");
    const Case = require("../../models/Case");
    const Appointment = require("../../models/Appointment");
    const Lawyer = require("../../models/Lawyer");

    const user = await User.findById(userId).select("+password");
    if (!user) {
      throw new AppError("User not found.", 404);
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      throw new AppError("Incorrect password.", 400);
    }

    // Clean up associated records
    await Case.deleteMany({ client: userId });
    await Appointment.deleteMany({ $or: [{ client: userId }, { lawyer: userId }] });
    await Lawyer.deleteOne({ user: userId });
    await User.findByIdAndDelete(userId);

    return true;
  }
}

module.exports = new AuthService();