const MB = 1024 * 1024;

module.exports = {
  // Largest document the AI Smart Case Assistant accepts. Larger files are
  // optimized first (images in the app, PDFs on the server).
  AI_MAX_FILE_BYTES: 3 * MB,

  // Largest raw PDF the server will attempt to optimize.
  AI_OPTIMIZE_MAX_INPUT_BYTES: 20 * MB,

  AI_MAX_DOCUMENTS: 10,
};
