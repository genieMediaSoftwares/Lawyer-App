const { generateAccessToken } = require("../config/jwt");

/**
 * Signs an access token for `user`.
 *
 * `sessionId` becomes the `sid` claim, which is how a token is tied to a row in
 * the session collection and therefore how logout can invalidate it. It is
 * optional only so that a caller with no session context still produces a
 * working token; every authentication path here passes one.
 */
const generateToken = (user, sessionId) => {
  const payload = {
    id: user._id,
    role: user.role,
    email: user.email,
  };

  if (sessionId) {
    payload.sid = sessionId;
  }

  return generateAccessToken(payload);
};

module.exports = generateToken;
