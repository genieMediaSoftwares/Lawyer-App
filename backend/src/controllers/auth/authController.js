const authService = require("../../services/auth/authService");
const storageService = require("../../services/storageService");
const ApiResponse = require("../../config/ApiResponse");
class AuthController {
  async signup(req, res, next) {
    try {
      const result = await authService.register(req.body);

      return ApiResponse.success(
        res,
        "User registered successfully.",
        result,
        201
      );
    } catch (error) {
      next(error);
    }
  }

  async login(req, res, next) {
    try {
      const { email, password } = req.body;

      const result = await authService.login(
        email,
        password
      );

      return ApiResponse.success(
        res,
        "Login successful.",
        result
      );
    } catch (error) {
      next(error);
    }
  }

  async profile(req, res, next) {
    try {
      const user = await authService.getProfile(
        req.user._id
      );

      return ApiResponse.success(
        res,
        "Profile fetched successfully.",
        user
      );
    } catch (error) {
      next(error);
    }
  }

  async updateProfile(req, res, next) {
    try {
      const { fullName, mobile } = req.body;
      const user = await authService.updateProfile(req.user._id, { fullName, mobile });

      return ApiResponse.success(
        res,
        "Profile updated successfully.",
        user
      );
    } catch (error) {
      next(error);
    }
  }

  async uploadProfileImage(req, res, next) {
    try {
      if (!req.file) {
        return ApiResponse.error(res, "No image file uploaded.", 400);
      }
      const metadata = await storageService.uploadFile(req.file, "profile");
      const user = await authService.updateProfile(req.user._id, { profileImage: metadata.url });

      return ApiResponse.success(
        res,
        "Profile image uploaded successfully.",
        user
      );
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();