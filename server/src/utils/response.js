/**
 * Consistent API response format.
 * Every route uses these helpers so the frontend always knows what to expect.
 *
 * Success: { success: true, data: {...}, message?: "..." }
 * Error:   { success: false, message: "...", errors?: [...] }
 */

const successResponse = (res, data, message = 'Success', statusCode = 200) => {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
  });
};

const errorResponse = (res, message = 'Server error', statusCode = 500, errors = null) => {
  const payload = { success: false, message };
  if (errors) payload.errors = errors;
  return res.status(statusCode).json(payload);
};

module.exports = { successResponse, errorResponse };
