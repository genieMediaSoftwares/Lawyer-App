/**
 * Answers any request that matched no route.
 *
 * Without this, Express's built-in finalhandler replies with an HTML page
 * reading `Cannot GET /uploads/cases/1789465124833-....pdf`. Production users
 * saw exactly that where a case attachment should have opened: `express.static`
 * calls next() when the file is not on disk, nothing was mounted after the
 * routes, and the app's error middleware never runs for an unmatched path
 * because a 4-argument handler only fires on next(err).
 *
 * Two things were wrong with that page. It is HTML, so a Flutter client
 * expecting JSON cannot turn it into a useful message; and it echoes the
 * request path, which tells a stranger how the server's storage is laid out.
 *
 * Mounted AFTER every route and BEFORE the error handler. It deliberately does
 * not distinguish "no such route" from "route exists, file gone" — both are
 * "not found" to the caller, and saying which would confirm what exists.
 */
const notFoundMiddleware = (req, res, next) => {
  // Headers already sent means something is mid-stream; let it finish.
  if (res.headersSent) return next();

  return res.status(404).json({
    success: false,
    message: "The requested resource could not be found.",
    code: "NOT_FOUND",
  });
};

module.exports = notFoundMiddleware;
