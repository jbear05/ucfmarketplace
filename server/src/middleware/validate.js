const { body, validationResult } = require('express-validator');
const { errorResponse } = require('../utils/response');

/**
 * Run after validation chains — returns 400 with all errors if any failed.
 * Usage: router.post('/register', registerRules, validate, handler)
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return errorResponse(
      res,
      'Validation failed',
      400,
      errors.array().map((e) => e.msg)
    );
  }
  next();
};

// ── Auth validation rules ─────────────────────────────────────────────────────

const registerRules = [
  body('name')
    .trim()
    .notEmpty().withMessage('Name is required')
    .isLength({ max: 60 }).withMessage('Name cannot exceed 60 characters'),
  body('email')
    .trim()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Enter a valid email address')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/\d/).withMessage('Password must contain at least one number'),
];

const loginRules = [
  body('email').trim().isEmail().withMessage('Enter a valid email').normalizeEmail(),
  body('password').notEmpty().withMessage('Password is required'),
];

const forgotPasswordRules = [
  body('email').trim().isEmail().withMessage('Enter a valid email').normalizeEmail(),
];

const resetPasswordRules = [
  body('password')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/\d/).withMessage('Password must contain at least one number'),
];

// ── Listing validation rules ──────────────────────────────────────────────────

const CATEGORIES = ['Textbooks', 'Electronics', 'Furniture', 'Clothing', 'Dorm & Home', 'Tickets & Events', 'Vehicles', 'Other'];
const CONDITIONS = ['New', 'Like New', 'Good', 'Fair', 'Poor'];

const listingRules = [
  body('title')
    .trim()
    .notEmpty().withMessage('Title is required')
    .isLength({ max: 100 }).withMessage('Title cannot exceed 100 characters'),
  body('price')
    .isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  body('category')
    .isIn(CATEGORIES).withMessage('Choose a valid category'),
  body('condition')
    .isIn(CONDITIONS).withMessage('Choose a valid condition'),
  body('meetupArea')
    .trim().notEmpty().withMessage('A general meetup area is required'),
];

const listingStatusRules = [
  body('status')
    .isIn(['active', 'pending', 'offMarket'])
    .withMessage('Status must be active, pending, or offMarket'),
];

// ── Message validation rules ──────────────────────────────────────────────────

const messageRules = [
  body('body')
    .trim()
    .notEmpty().withMessage('Message cannot be empty')
    .isLength({ max: 2000 }).withMessage('Message cannot exceed 2000 characters'),
];

// ── Meetup validation rules ────────────────────────────────────────────────────

const meetupRules = [
  body('address')
    .trim().notEmpty().withMessage('A meetup address is required'),
  body('lat')
    .isFloat({ min: -90, max: 90 }).withMessage('A valid latitude is required'),
  body('lng')
    .isFloat({ min: -180, max: 180 }).withMessage('A valid longitude is required'),
];

// ── Rating validation rules ────────────────────────────────────────────────────

const rateRules = [
  body('score')
    .isInt({ min: 1, max: 5 }).withMessage('Score must be between 1 and 5'),
  body('feedback')
    .optional({ checkFalsy: true })
    .trim().isLength({ max: 500 }).withMessage('Feedback cannot exceed 500 characters'),
];

module.exports = {
  validate,
  registerRules,
  loginRules,
  forgotPasswordRules,
  resetPasswordRules,
  listingRules,
  listingStatusRules,
  messageRules,
  meetupRules,
  rateRules,
};
