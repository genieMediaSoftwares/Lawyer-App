const errorMiddleware = (
  err,
  req,
  res,
  next
) => {
  console.error(err);

  let message = err.message || "Internal Server Error";
  let statusCode = err.statusCode || 500;

  if (err.code === "LIMIT_FILE_SIZE") {
    message = "Maximum allowed file size is 10 MB.";
    statusCode = 400;
  }

  res.status(statusCode).json({
    success: false,
    message: message,
  });
};

module.exports = errorMiddleware;