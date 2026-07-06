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
}

module.exports = new AuthService();