const userRepository = require("../../repositories/userRepository");
const generateToken = require("../../utils/generateToken");
const AppError = require("../../utils/AppError");


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

    // Create User
    const user = await userRepository.create(userData);

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
    if (!user) {
      throw new AppError("User with this email does not exist.", 404);
    }

    const resetToken = Math.floor(100000 + Math.random() * 900000).toString(); // 6 digit OTP
    user.resetPasswordToken = resetToken;
    user.resetPasswordExpire = Date.now() + 3600000; // 1 hour
    await user.save();

    return { resetToken };
  }

  async resetPassword(email, token, newPassword) {
    const User = require("../../models/User");
    const user = await User.findOne({
      email,
      resetPasswordToken: token,
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
}

module.exports = new AuthService();