const notificationService = require("../services/notification/notificationService");

module.exports = (io) => {
  const notificationNamespace = io.of("/notifications");

  // Initialize service with Socket.IO
  notificationService.init(io);

  notificationNamespace.on("connection", (socket) => {
    console.log(`🔌 Notification Socket connected: ${socket.id}`);

    // Join personal user room to receive targeted alerts
    socket.on("register", ({ userId }) => {
      if (userId) {
        socket.join(userId);
        console.log(`🔔 User registered notifications: ${userId}`);
      }
    });

    socket.on("disconnect", () => {
      console.log(`🔌 Notification Socket disconnected: ${socket.id}`);
    });
  });
};
