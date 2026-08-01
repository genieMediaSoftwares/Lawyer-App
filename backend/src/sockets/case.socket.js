const socketAuth = require("./socketAuth");

module.exports = (io) => {
  const caseNamespace = io.of("/cases");

  caseNamespace.use(socketAuth);

  caseNamespace.on("connection", (socket) => {
    const userId = socket.userId;
    console.log(`🔌 Case Socket connected: ${socket.id} (user ${userId})`);

    socket.join(userId);
    console.log(`💼 User registered cases: ${userId}`);


    socket.on("disconnect", () => {
      console.log(`🔌 Case Socket disconnected: ${socket.id}`);
    });
  });
};
