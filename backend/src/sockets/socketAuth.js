const jwt = require("jsonwebtoken");

/**
 * Socket.IO handshake authentication.
 *
 * Every namespace must install this. Without it the server accepted anonymous
 * connections and let the client name its own rooms, so anyone could join an
 * arbitrary chat conversation or another user's private notification room
 * simply by emitting the corresponding id.
 *
 * The verified id is attached as `socket.userId` and is the *only* identity
 * handlers may trust — never a userId taken from the event payload.
 *
 * Clients authenticate with:
 *   io(url, { auth: { token: "<jwt>" } })
 */
const socketAuth = (socket, next) => {
  const token =
    socket.handshake.auth?.token ||
    socket.handshake.headers?.authorization?.replace(/^Bearer /, "");

  if (!token) {
    return next(new Error("Unauthorized: no token provided"));
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = decoded.id.toString();
    socket.userRole = decoded.role;
    return next();
  } catch (error) {
    return next(new Error("Unauthorized: invalid or expired token"));
  }
};

module.exports = socketAuth;
