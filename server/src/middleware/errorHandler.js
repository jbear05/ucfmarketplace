const { errorResponse } = require('../utils/response');

/**
 * Global error handler — must be registered LAST in Express app.
 * Catches anything next(err) passes through.
 */
const errorHandler = (err, req, res, _next) => {
  console.error(`[ERROR] ${req.method} ${req.path}:`, err.message);

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    const errors = Object.values(err.errors).map((e) => e.message);
    return errorResponse(res, 'Validation failed', 400, errors);
  }

  // Mongoose duplicate key (e.g. email already exists)
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue)[0];
    return errorResponse(res, `${field} already in use`, 409);
  }

  // Mongoose invalid ObjectId
  if (err.name === 'CastError') {
    return errorResponse(res, 'Invalid ID format', 400);
  }

  // Multer file size error
  if (err.code === 'LIMIT_FILE_SIZE') {
    return errorResponse(res, 'Image too large — max 5MB per image', 400);
  }

  // JWT errors (handled in auth middleware, but just in case)
  if (err.name === 'JsonWebTokenError') {
    return errorResponse(res, 'Invalid token', 401);
  }

  // Default — 500
  return errorResponse(
    res,
    process.env.NODE_ENV === 'production' ? 'Server error' : err.message,
    err.statusCode || 500
  );
};

/**
 * 404 handler — catches requests to undefined routes.
 * Register BEFORE errorHandler but AFTER all routes.
 */
const notFound = (req, res) => {
  return errorResponse(res, `Route not found: ${req.method} ${req.path}`, 404);
};

module.exports = { errorHandler, notFound };
