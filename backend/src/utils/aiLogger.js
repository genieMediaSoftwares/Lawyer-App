const logger = require("./logger");

/**
 * Logging for the AI Smart Case intake, on top of the app's structured logger.
 *
 * The intake is the one flow in this codebase that runs *detached* from the
 * request that started it: the HTTP response is already sent when OCR,
 * transcription and extraction happen, so a failure there reaches no client and
 * appears in no request log. Every transition and every failure in that
 * pipeline goes through here instead, tagged with the session id, so one run
 * can be reconstructed end to end from the logs.
 *
 * Two things this adds over the base logger:
 *
 *  * A `scope` of `ai-smart-case` on every line, so the pipeline can be
 *    filtered out of an otherwise busy log.
 *  * An `error(event, err, meta)` signature that serialises the error rather
 *    than letting `JSON.stringify` turn an `Error` into `{}` — which is what
 *    the base logger does with one, and why several pipeline failures were
 *    logged as an empty object.
 */

const SCOPE = "ai-smart-case";

/** ObjectIds and other Mongoose values stringify usefully; nulls are dropped. */
function normalise(meta = {}) {
  const out = { scope: SCOPE };
  for (const [key, value] of Object.entries(meta)) {
    if (value === undefined || value === null) continue;
    out[key] = typeof value === "object" && value.toString ? value.toString() : value;
  }
  return out;
}

function serialiseError(err) {
  if (!err) return { error: "unknown" };
  if (err instanceof Error) {
    return {
      error: err.message,
      errorName: err.name,
      // Truncated: a full Node stack is mostly framework frames and pushes the
      // useful lines out of a log viewer's default width.
      stack: (err.stack || "").split("\n").slice(0, 6).join(" | "),
    };
  }
  return { error: String(err) };
}

module.exports = {
  debug: (event, meta) => logger.debug(event, normalise(meta)),
  info: (event, meta) => logger.info(event, normalise(meta)),
  warn: (event, meta) => logger.warn(event, normalise(meta)),
  error: (event, err, meta) =>
    logger.error(event, { ...normalise(meta), ...serialiseError(err) }),
};
