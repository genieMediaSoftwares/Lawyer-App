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
      const { fullName, mobile, location } = req.body;
      const user = await authService.updateProfile(req.user._id, { fullName, mobile, location });

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

  async forgotPassword(req, res, next) {
    try {
      const { email } = req.body;
      if (!email) {
        return ApiResponse.error(res, "Email is required.", 400);
      }
      const result = await authService.forgotPassword(email);
      return ApiResponse.success(res, "Password reset code generated.", result);
    } catch (error) {
      next(error);
    }
  }

  async resetPassword(req, res, next) {
    try {
      const { email, token, newPassword } = req.body;
      if (!email || !token || !newPassword) {
        return ApiResponse.error(res, "Email, token, and newPassword are required.", 400);
      }
      await authService.resetPassword(email, token, newPassword);
      return ApiResponse.success(res, "Password has been reset successfully.");
    } catch (error) {
      next(error);
    }
  }

  async changePassword(req, res, next) {
    try {
      const { oldPassword, newPassword } = req.body;
      if (!oldPassword || !newPassword) {
        return ApiResponse.error(res, "Old and new passwords are required.", 400);
      }
      await authService.changePassword(req.user._id, oldPassword, newPassword);
      return ApiResponse.success(res, "Password changed successfully.");
    } catch (error) {
      next(error);
    }
  }

  async uploadBarCertificate(req, res, next) {
    try {
      if (!req.file) {
        return ApiResponse.error(res, "No certificate file uploaded.", 400);
      }
      const Lawyer = require("../../models/Lawyer");
      const metadata = await storageService.uploadFile(req.file, "certificates");
      const lawyer = await Lawyer.findOneAndUpdate(
        { user: req.user._id },
        { barCertificate: metadata.url },
        { new: true }
      );
      if (!lawyer) {
        return ApiResponse.error(res, "Lawyer profile not found.", 404);
      }
      return ApiResponse.success(res, "Bar certificate uploaded successfully.", lawyer);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();