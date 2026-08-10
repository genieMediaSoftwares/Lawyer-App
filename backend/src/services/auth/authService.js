const crypto = require("crypto");

const userRepository = require("../../repositories/userRepository");
const generateToken = require("../../utils/generateToken");
const AppError = require("../../utils/AppError");
const AUTH_CODES = require("../../utils/authCodes");
const normalizeEmail = require("../../utils/normalizeEmail");
const sessionService = require("./sessionService");

// Reset codes are stored hashed, so the lookup in resetPassword has to hash the
// candidate the same way. SHA-256 is appropriate here (unlike for passwords):
// the input is high-entropy and short-lived, and the comparison must be fast.
const hashResetToken = (token) =>
  crypto.createHash("sha256").update(String(token)).digest("hex");

/**
 * Whether two people may share a display name.
 *
 * The User schema puts a unique index on `email` and `mobile` and deliberately
 * none on `fullName`, because real names collide — refusing the second "Priya
 * Sharma" to register would be a bug, not a safeguard. The uniqueness check is
 * therefore off, and this flag is the single place to turn it on if the product
 * ever grows a genuine handle. Switching it to true also needs a unique index
 * on the collection; the check below is a courtesy message, not the guarantee.
 */
const REQUIRE_UNIQUE_FULL_NAME = false;

/**
 * Maps a duplicate-key error from Mongo onto the field that actually collided.
 *
 * The pre-insert existence checks lose to a race: two signups with the same
 * address, close enough together that both read "no such user" before either
 * writes, and the loser comes back as E11000. That used to fall through to the
 * generic handler, which answered 500 with the driver's own message — index
 * name, collection name and the offending value included. Same rejection, same
 * wording as the checked path, so the race is invisible to the user.
 */
const duplicateKeyError = (error) => {
  if (!error || error.code !== 11000) {
    return null;
  }

  // keyPattern is the reliable source; the message is a fallback for driver
  // versions that omit it.
  const field =
    Object.keys(error.keyPattern || {})[0] ||
    (/email/i.test(error.message || "")
      ? "email"
      : /mobile/i.test(error.message || "")
      ? "mobile"
      : null);

  if (field === "email") {
    return new AppError(
      "This email is already registered. Please use another email or sign in.",
      409,
      AUTH_CODES.EMAIL_ALREADY_REGISTERED
    );
  }

  if (field === "mobile") {
    return new AppError(
      "This mobile number is already registered. Please use another number or sign in.",
      409,
      AUTH_CODES.MOBILE_ALREADY_REGISTERED
    );
  }

  if (field === "fullName") {
    return new AppError(
      "This name is already in use. Please choose another name.",
      409,
      AUTH_CODES.NAME_ALREADY_IN_USE
    );
  }

  return new AppError(
    "An account with these details already exists.",
    409,
    AUTH_CODES.EMAIL_ALREADY_REGISTERED
  );
};

/** The user-facing shape of an account. Never includes the password hash. */
const publicUser = (user) => ({
  id: user._id,
  fullName: user.fullName,
  email: user.email,
  mobile: user.mobile,
  role: user.role,
  profileImage: user.profileImage,
  location: user.location || "",
});

class AuthService {
  /**
   * Register User
   *
   * @param {object} userData
   * @param {object} [context]  Device the signup came from, so the session this
   *                            opens can be recognised as the same device when
   *                            the user signs in from it a moment later.
   */
  async register(userData, context = {}) {
    const email = normalizeEmail(userData.email);
    const mobile =
      typeof userData.mobile === "string"
        ? userData.mobile.trim()
        : userData.mobile;

    // Check Email
    const emailExists = await userRepository.findByEmail(email);

    if (emailExists) {
      throw new AppError(
        "This email is already registered. Please use another email or sign in.",
        409,
        AUTH_CODES.EMAIL_ALREADY_REGISTERED
      );
    }

    // Check Mobile
    const mobileExists = await userRepository.findByMobile(mobile);

    if (mobileExists) {
      throw new AppError(
        "This mobile number is already registered. Please use another number or sign in.",
        409,
        AUTH_CODES.MOBILE_ALREADY_REGISTERED
      );
    }

    // Off by default — see REQUIRE_UNIQUE_FULL_NAME.
    if (REQUIRE_UNIQUE_FULL_NAME) {
      const nameExists = await userRepository.findByFullName(userData.fullName);

      if (nameExists) {
        throw new AppError(
          "This name is already in use. Please choose another name.",
          409,
          AUTH_CODES.NAME_ALREADY_IN_USE
        );
      }
    }

    // Allowlist the fields a self-registering user is permitted to set.
    // Never hand the raw request body to Mongoose: privileged schema fields
    // (isVerified, isActive, role="admin") would otherwise be mass-assignable.
    // `isVerified` in particular is the same flag the admin verification flow
    // sets, so an attacker could self-register as a verified advocate.
    let user;
    try {
      user = await userRepository.create({
        fullName: userData.fullName,
        email,
        mobile,
        password: userData.password,
        role: userData.role === "lawyer" ? "lawyer" : "client",
      });
    } catch (error) {
      // The checks above read the collection; the unique indexes enforce it.
      // Between the two sits a window in which a concurrent signup can claim
      // the same address, and this is what closes it.
      const duplicate = duplicateKeyError(error);
      if (duplicate) {
        throw duplicate;
      }
      throw error;
    }

    // Signing up leaves the account signed in on this device, exactly as
    // logging in would. Registering the session here rather than issuing a
    // sessionless token keeps every live token accounted for — and because the
    // device id is the same one the login flow sends, the "please log in" step
    // that follows signup replaces this session instead of colliding with it.
    const sessionId = await sessionService.createSession({
      userId: user._id,
      deviceId: context.deviceId,
      ipAddress: context.ipAddress,
    });

    // Generate JWT
    const token = generateToken(user, sessionId);

    return {
      token,
      user: publicUser(user),
    };
  }

  /**
   * Login User
   *
   * @param {string} email
   * @param {string} password
   * @param {object} [context]  `deviceId` identifies the installation the
   *                            request came from and decides whether an
   *                            existing session is this user's own or a genuine
   *                            second device.
   */
  async login(email, password, context = {}) {
    const user = await userRepository.findByEmail(email);

    // One message and one code for "no such account" and "wrong password".
    // Distinguishing them would let anyone test which addresses are registered.
    if (!user) {
      throw new AppError(
        "Invalid email or password.",
        401,
        AUTH_CODES.INVALID_CREDENTIALS
      );
    }

    const isPasswordCorrect =
      await user.comparePassword(password);

    if (!isPasswordCorrect) {
      throw new AppError(
        "Invalid email or password.",
        401,
        AUTH_CODES.INVALID_CREDENTIALS
      );
    }

    // Credentials are settled before any session work, so a wrong password
    // always reports itself as a wrong password. The old flow had no session
    // check at all and the only thing that ever interrupted a login was the
    // rate limiter, which is why every kind of failure — including this one —
    // could surface as "Too many attempts. Please try again later."
    const { deviceId, ipAddress } = context;

    // Re-authenticating from the same installation replaces its own session
    // rather than conflicting with it. This is the common case: the app was
    // killed, or storage was cleared, so logout never ran.
    await sessionService.revokeSessionsForDevice(user._id, deviceId);

    const activeSession = await sessionService.findActiveSession(user._id);

    if (activeSession) {
      throw new AppError(
        "This account is already logged in on another device.",
        409,
        AUTH_CODES.ACTIVE_SESSION_EXISTS
      );
    }

    const sessionId = await sessionService.createSession({
      userId: user._id,
      deviceId,
      ipAddress,
    });

    const token = generateToken(user, sessionId);

    return {
      token,
      user: publicUser(user),
    };
  }

  /**
   * Ends the session the caller's token names.
   *
   * Signing out has to reach the server, or the row stays live and the user is
   * told they are "already logged in on another device" the next time they try
   * — from any device, including the one they just left. Idempotent, so a
   * repeated or racing logout is not an error.
   */
  async logout(sessionId) {
    await sessionService.revokeSession(sessionId);
    return true;
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
    // Normalised for the same reason login is: an address typed with different
    // casing found nothing here, and because this endpoint answers identically
    // either way, the failure was silent — no email arrived and no error said
    // why.
    const user = await User.findOne({ email: normalizeEmail(email) });
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
      email: normalizeEmail(email),
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
    // Sessions outlive the account otherwise: the rows sit there until their
    // TTL, and any token still in hand keeps passing the session check even
    // though the user it names no longer exists.
    await sessionService.revokeAllSessions(userId);
    await User.findByIdAndDelete(userId);

    return true;
  }
}

module.exports = new AuthService();