const User = require("../models/User");

class UserRepository {
  /**
   * Create User
   */
  async create(userData) {
    return await User.create(userData);
  }

  /**
   * Find by Email
   */
  async findByEmail(email) {
    return await User.findOne({ email }).select("+password");
  }

  /**
   * Find by Mobile
   */
  async findByMobile(mobile) {
    return await User.findOne({ mobile }).select("+password");
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