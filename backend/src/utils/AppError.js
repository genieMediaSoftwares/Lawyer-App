class AppError extends Error {
  /**
   * @param {string} message  Shown to the user as-is. Never put a driver or
   *                          database message in here.
   * @param {number} statusCode
   * @param {string} [code]   Stable identifier from utils/authCodes, echoed in
   *                          the response body so the client can branch on the
   *                          reason rather than on the wording.
   */
  constructor(message, statusCode, code) {
    super(message);

    this.statusCode = statusCode;
    this.code = code;

    // Marks this as a failure we raised on purpose and whose message is safe to
    // show. errorMiddleware uses it to decide what may cross the wire: anything
    // without it is an unexpected throw and gets a generic message instead.
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
