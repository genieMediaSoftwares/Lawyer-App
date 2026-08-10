const User = require("../models/User");
const normalizeEmail = require("../utils/normalizeEmail");

class UserRepository {
  /**
   * Create User
   */
  async create(userData) {
    return await User.create(userData);
  }

  /**
   * Find by Email
   *
   * Normalised at the query, not just at the write. Mongoose's `lowercase: true`
   * never touches query values, so an address typed with different casing used
   * to miss the stored row entirely — see utils/normalizeEmail.
   */
  async findByEmail(email) {
    return await User.findOne({ email: normalizeEmail(email) }).select(
      "+password"
    );
  }

  /**
   * Find by Mobile
   */
  async findByMobile(mobile) {
    return await User.findOne({
      mobile: typeof mobile === "string" ? mobile.trim() : mobile,
    }).select("+password");
  }

  /**
   * Find by exact display name, case-insensitively.
   *
   * Only used when unique display names are switched on; see
   * authService.register. Anchored and escaped so a name containing regex
   * metacharacters is matched literally rather than compiled as a pattern.
   */
  async findByFullName(fullName) {
    if (typeof fullName !== "string" || !fullName.trim()) {
      return null;
    }

    const escaped = fullName.trim().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    return await User.findOne({
      fullName: { $regex: `^${escaped}$`, $options: "i" },
    });
  }

  /**
   * Find by ID
   */
  async findById(id) {
    return await User.findById(id);
  }

  /**
   * Update User
   */
  async update(id, data) {
    return await User.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    });
  }

  /**
   * Delete User
   */
  async delete(id) {
    return await User.findByIdAndDelete(id);
  }
}

module.exports = new UserRepository();
