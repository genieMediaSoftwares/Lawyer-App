const socketAuth = require("./socketAuth");

module.exports = (io) => {
  const caseNamespace = io.of("/cases");

  caseNamespace.use(socketAuth);

  caseNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    console.log(`🔌 Case Socket connected: ${socket.id} (user ${userId})`);

    // Joined from the verified token rather than a client-supplied "join"
    // payload, which previously allowed listening to anyone's case updates.
    socket.join(userId);
    console.log(`💼 User registered cases: ${userId}`);

    socket.on("disconnect", () => {
      console.log(`🔌 Case Socket disconnected: ${socket.id}`);
    });
  });
};
