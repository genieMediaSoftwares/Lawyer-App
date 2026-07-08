module.exports = (io) => {
  const caseNamespace = io.of("/cases");

  caseNamespace.on("connection", (socket) => {
    console.log(`🔌 Case Socket connected: ${socket.id}`);

    // Join personal user room to receive targeted case updates
    socket.on("join", ({ userId }) => {
      socket.join(userId);
      console.log(`💼 User registered cases: ${userId}`);
    });

    socket.on("disconnect", () => {
      console.log(`🔌 Case Socket disconnected: ${socket.id}`);
    });
  });
};
