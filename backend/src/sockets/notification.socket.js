const notificationService = require("../services/notification/notificationService");
const socketAuth = require("./socketAuth");

module.exports = (io) => {
  const notificationNamespace = io.of("/notifications");

  // Initialize service with Socket.IO
  notificationService.init(io);

  notificationNamespace.use(socketAuth);

  notificationNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    console.log(`🔌 Notification Socket connected: ${socket.id} (user ${userId})`);

    // Joined from the verified token rather than a client-supplied "register"
    // payload, which previously allowed subscribing to anyone's alert stream.
    socket.join(userId);
    console.log(`🔔 User registered notifications: ${userId}`);

    socket.on("disconnect", () => {
      console.log(`🔌 Notification Socket disconnected: ${socket.id}`);
    });
  });
};
