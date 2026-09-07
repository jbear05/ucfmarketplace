const jwt  = require('jsonwebtoken');
const User = require('../models/User');
const { errorResponse } = require('../utils/response');

/**
 * protect — verifies JWT, attaches req.user to every protected route.
 * Usage: router.get('/me', protect, handler)
 */
const protect = async (req, res, next) => {
  try {
    // Accept token from Authorization header OR cookie
    let token;
    if (req.headers.authorization?.startsWith('Bearer ')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return errorResponse(res, 'Not authenticated — please log in', 401);
    }

    // Verify signature + expiry
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Fetch fresh user — catches deleted/blocked accounts mid-session
    const user = await User.findById(decoded.id).select(
      '+isEmailConfirmed +isBlocked'
    );

    if (!user) {
      return errorResponse(res, 'User no longer exists', 401);
    }

    if (user.isBlocked) {
      return errorResponse(res, 'Your account has been suspended', 403);
    }

    if (!user.isEmailConfirmed) {
      return errorResponse(res, 'Please verify your email before continuing', 403);
    }

    req.user = user;

    // Bump last-activity timestamp — fire-and-forget, doesn't block the request
    User.updateOne({ _id: user._id }, { lastActiveAt: new Date() }).catch(() => {});

    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return errorResponse(res, 'Session expired — please log in again', 401);
    }
    return errorResponse(res, 'Invalid token', 401);
  }
};

/**
 * adminOnly — must come AFTER protect.
 * Usage: router.get('/admin/users', protect, adminOnly, handler)
 */
const adminOnly = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return errorResponse(res, 'Admin access required', 403);
  }
  next();
};

/**
 * optionalAuth — attaches req.user if token present, but doesn't block.
 * Used for public routes that behave differently when logged in
 * (e.g. listings page — shows heart state if authenticated).
 */
const optionalAuth = async (req, res, next) => {
  try {
    let token;
    if (req.headers.authorization?.startsWith('Bearer ')) {
      token = req.headers.authorization.split(' ')[1];
    }
    if (!token) return next(); // no token — fine, continue as guest

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user    = await User.findById(decoded.id);
    if (user && !user.isBlocked) req.user = user;
  } catch {
    // Invalid token — treat as guest, don't throw
  }
  next();
};

/**
 * generateToken — creates a signed JWT for a user ID.
 */
const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

module.exports = { protect, adminOnly, optionalAuth, generateToken };
