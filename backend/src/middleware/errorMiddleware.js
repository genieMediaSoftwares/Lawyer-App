/**
 * Turns a schema path into something a person can read.
 *
 * Array paths arrive as "documents.0.url"; the index is dropped because the
 * client shows one message per field, not per element.
 */
function readableFieldName(path) {
  const last = String(path)
    .split(".")
    .filter((part) => !/^\d+$/.test(part))
    .join(" ");

  const spaced = last.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();
  return spaced.charAt(0).toUpperCase() + spaced.slice(1);
}

const AppError = require("../utils/AppError");

/**
 * Rewrites failures that originate below the application layer.
 *
 * Anything thrown by Mongo, Mongoose or jsonwebtoken carries an operator's
 * message, not a user's: index names, collection names, cast failures, and in
 * the duplicate-key case the offending value itself. Those were being copied
 * straight into the response body, so a signup that lost a race told the user
 * about `E11000 duplicate key error collection: law.users index: email_1`.
 *
 * Returns a replacement {message, statusCode, code} for the errors it
 * recognises, or null to leave the error alone — which is deliberate for
 * everything the application raises on purpose, including plain Errors thrown
 * by services whose messages are written for the user.
 */
const translateInfrastructureError = (err) => {
  // Duplicate key. Services that expect one map it to the right field before
  // it reaches here; this is the backstop for every other collection.
  if (err.code === 11000) {
    const field = Object.keys(err.keyPattern || {})[0];
    return {
      statusCode: 409,
      message: field
        ? `This ${field} is already in use.`
        : "This record already exists.",
      code: "DUPLICATE_KEY",
    };
  }

  // Schema validation. The field names are ours and safe to name; the rest of
  // the Mongoose message is not.
  if (err.name === "ValidationError" && err.errors) {
    const names = Object.keys(err.errors);

    // A per-field map, so the client can mark the offending input instead of
    // showing one sentence listing field names. The text is composed HERE from
    // the KIND of failure — never from err.errors[x].message, which carries
    // Mongoose's own wording, the model name and sometimes the rejected value.
    const fields = {};
    for (const name of names) {
      const detail = err.errors[name];
      const label = readableFieldName(name);

      switch (detail?.kind) {
        case "required":
          fields[name] = `${label} is required.`;
          break;
        case "enum":
          fields[name] = `${label} is not one of the accepted values.`;
          break;
        case "ObjectId":
          fields[name] = `${label} is not a valid reference.`;
          break;
        case "Number":
        case "Date":
          fields[name] = `${label} is not a valid ${detail.kind.toLowerCase()}.`;
          break;
        case "minlength":
        case "maxlength":
          fields[name] = `${label} is not an accepted length.`;
          break;
        default:
          fields[name] = `${label} is not valid.`;
      }
    }

    return {
      statusCode: 400,
      message: names.length
        ? "Some of the details provided are not valid."
        : "Some of the details provided are not valid.",
      code: "VALIDATION_ERROR",
      fields,
    };
  }

  // A malformed ObjectId in a route parameter. Reported as a 500 before, with
  // the raw cast failure attached.
  if (err.name === "CastError") {
    return {
      statusCode: 400,
      message: "The requested record could not be found.",
      code: "INVALID_IDENTIFIER",
    };
  }

  if (err.name === "JsonWebTokenError" || err.name === "TokenExpiredError") {
    return {
      statusCode: 401,
      message: "Invalid or expired token.",
      code: "INVALID_TOKEN",
    };
  }

  if (err.name === "MongoServerError" || err.name === "MongoNetworkError") {
    return {
      statusCode: 503,
      message: "Service temporarily unavailable. Please try again.",
      code: "SERVICE_UNAVAILABLE",
    };
  }

  return null;
};

const errorMiddleware = (
  err,
  req,
  res,
  next
) => {
  // Full detail stays in the server log — this is where an operator looks.
  // Failures we raise on purpose (a wrong password, a duplicate signup) are
  // routine and get one line; anything else gets the stack, because it is a
  // bug somebody has to find.
  if (err instanceof AppError) {
    console.warn(`${req.method} ${req.originalUrl} → ${err.statusCode} ${err.code || ""}`.trim());
  } else {
    console.error(err);
  }

  let message = err.message || "Internal Server Error";
  let statusCode = err.statusCode || 500;
  let code = err instanceof AppError ? err.code : undefined;
  // Per-field detail, when the translator produced any.
  let fields;

  if (err.code === "LIMIT_FILE_SIZE") {
    message = "Maximum allowed file size is 10 MB.";
    statusCode = 400;
    code = "FILE_TOO_LARGE";
  } else {
    const translated = translateInfrastructureError(err);
    if (translated) {
      ({ message, statusCode, code } = translated);
      // Destructuring the three named keys alone silently dropped `fields`, so
      // the per-field map never reached the client.
      fields = translated.fields;
    }
  }

  const body = {
    success: false,
    message,
    ...(code ? { code } : {}),
    ...(fields && Object.keys(fields).length ? { fields } : {}),
  };

  res.status(statusCode).json(body);
};

module.exports = errorMiddleware;
