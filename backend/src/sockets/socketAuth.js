const jwt = require("jsonwebtoken");
const sessionService = require("../services/auth/sessionService");

const socketAuth = async (socket, next) => {
  const token =
    socket.handshake.auth?.token ||
    socket.handshake.headers?.authorization?.replace(/^Bearer /, "");

  if (!token) {
    return next(new Error("Unauthorized: no token provided"));
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.sid && !(await sessionService.isSessionActive(decoded.sid))) {
      return next(new Error("Unauthorized: session has ended"));
    }
    socket.userId = decoded.id.toString();
    socket.userRole = decoded.role;
    return next();
  } catch (error) {
    return next(new Error("Unauthorized: invalid or expired token"));
  }
};

module.exports = socketAuth;
