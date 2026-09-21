const MB = 1024 * 1024;

const readMegabytes = (value, fallback) => {
  const parsed = Number.parseFloat(value ?? "");
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

// Largest document the AI Smart Case Assistant accepts, after optimization.
const AI_UPLOAD_MAX_MB = readMegabytes(process.env.AI_UPLOAD_MAX_MB, 3);

// Largest original the optimize endpoint will receive and try to shrink. Only
// that endpoint allows it; it is never a file size the application keeps.
const AI_OPTIMIZE_MAX_MB = Math.max(
  readMegabytes(process.env.AI_OPTIMIZE_MAX_MB, 20),
  AI_UPLOAD_MAX_MB
);

const formatMb = (mb) => `${Number.isInteger(mb) ? mb : mb.toFixed(1)} MB`;

module.exports = {
  AI_MAX_FILE_BYTES: Math.floor(AI_UPLOAD_MAX_MB * MB),
  AI_OPTIMIZE_MAX_INPUT_BYTES: Math.floor(AI_OPTIMIZE_MAX_MB * MB),
  AI_MAX_FILE_LABEL: formatMb(AI_UPLOAD_MAX_MB),
  AI_OPTIMIZE_MAX_LABEL: formatMb(AI_OPTIMIZE_MAX_MB),
  AI_MAX_DOCUMENTS: 10,
};
