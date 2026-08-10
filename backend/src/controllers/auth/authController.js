const authService = require("../../services/auth/authService");
const storageService = require("../../services/storageService");
const ApiResponse = require("../../config/ApiResponse");

/**
 * Identifies the installation a request came from, for session tracking.
 *
 * The client sends a value it generated once and keeps in secure storage, so
 * "the same device" survives a restart, an app update and a cleared session.
 * An older build that sends nothing yields an undefined id: sessionService
 * treats that as "no device match", so such a client can still sign in and
 * still gets the active-session check — it just cannot claim an earlier
 * session as its own. The header is accepted as a fallback for requests with
 * no body of their own, such as logout.
 */
const deviceContext = (req) => ({
  deviceId: req.body?.deviceId || req.get("X-Device-Id") || undefined,
  ipAddress: req.ip,
});

class AuthController {
  async signup(req, res, next) {
    try {
      const result = await authService.register(req.body, deviceContext(req));

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
        password,
        deviceContext(req)
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

  /**
   * Ends the session this token names.
   *
   * `req.sessionId` is set by authMiddleware from the token's `sid` claim, so
   * a caller can only ever end their own session. Tokens issued before session
   * tracking existed carry no `sid`; there is nothing to revoke for those, and
   * reporting success is right — the client clears its local state either way.
   */
  async logout(req, res, next) {
    try {
      await authService.logout(req.sessionId);

      return ApiResponse.success(res, "Logged out successfully.");
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
      await authService.forgotPassword(email);

      // Deliberately neutral, and carries no payload: the reset code goes out
      // by email only. Returning it here (or varying the response for unknown
      // addresses) is what made account takeover trivial.
      return ApiResponse.success(
        res,
        "If that email is registered, a reset code has been sent."
      );
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
  async deleteAccount(req, res, next) {
    try {
      const { password } = req.body;
      if (!password) {
        return ApiResponse.error(res, "Password is required to delete account.", 400);
      }
      await authService.deleteAccount(req.user._id, password);
      return ApiResponse.success(res, "Account deleted successfully.");
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();