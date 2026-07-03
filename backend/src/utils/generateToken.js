const { generateAccessToken } = require("../config/jwt");

const generateToken = (user) => {
  return generateAccessToken({
    id: user._id,
    role: user.role,
    email: user.email,
  });
};

module.exports = generateToken;