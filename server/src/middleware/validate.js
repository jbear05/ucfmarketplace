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

// Same rule as the mobile register screen — UCF students and staff only
const UCF_EMAIL_RE = /^[^\s@]+@(knights\.)?ucf\.edu$/i;

const registerRules = [
  body('name')
    .trim()
    .notEmpty().withMessage('Name is required')
    .isLength({ max: 60 }).withMessage('Name cannot exceed 60 characters'),
  body('email')
    .trim()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Enter a valid email address')
    .matches(UCF_EMAIL_RE).withMessage('Use your @ucf.edu or @knights.ucf.edu email')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/\d/).withMessage('Password must contain at least one number'),
  body('agreedToRules')
    .custom((v) => v === true || v === 'true').withMessage('You must agree to the community rules'),
];

const updateMeRules = [
  body('name')
    .optional()
    .trim()
    .notEmpty().withMessage('Name cannot be empty')
    .isLength({ max: 60 }).withMessage('Name cannot exceed 60 characters'),
  body('classYear')
    .optional({ checkFalsy: true })
    .trim()
    .matches(/^\d{2}(\d{2})?$/).withMessage('Class year should look like 27 or 2027'),
  body('emailPriceDrop')
    .optional()
    .isBoolean().withMessage('emailPriceDrop must be true or false'),
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
const CAMPUSES   = ['Main Campus', 'Downtown', 'Rosen', 'Lake Nona'];

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
  body('campus')
    .isIn(CAMPUSES).withMessage('Choose a valid campus'),
  body('isAiGenerated')
    .optional()
    .isBoolean().withMessage('isAiGenerated must be true or false'),
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
  // Optional — a curated spot may not have coordinates
  body('lat')
    .optional()
    .isFloat({ min: -90, max: 90 }).withMessage('A valid latitude is required'),
  body('lng')
    .optional()
    .isFloat({ min: -180, max: 180 }).withMessage('A valid longitude is required'),
];

// ── Saved search validation rules ─────────────────────────────────────────────

const savedSearchRules = [
  body('label')
    .trim()
    .notEmpty().withMessage('Give your search a name')
    .isLength({ max: 60 }).withMessage('Name cannot exceed 60 characters'),
  body('filters.search')
    .optional().isString().trim().isLength({ max: 100 }).withMessage('Search text is too long'),
  body('filters.category')
    .optional().isIn(CATEGORIES).withMessage('Choose a valid category'),
  body('filters.condition')
    .optional().isIn(CONDITIONS).withMessage('Choose a valid condition'),
  body('filters.campus')
    .optional().isIn(CAMPUSES).withMessage('Choose a valid campus'),
  body('filters.minPrice')
    .optional().isFloat({ min: 0 }).withMessage('Min price must be a positive number'),
  body('filters.maxPrice')
    .optional().isFloat({ min: 0 }).withMessage('Max price must be a positive number'),
  body('filters.hideAiGenerated')
    .optional().isBoolean().withMessage('hideAiGenerated must be true or false'),
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
  updateMeRules,
  loginRules,
  forgotPasswordRules,
  resetPasswordRules,
  listingRules,
  listingStatusRules,
  messageRules,
  meetupRules,
  savedSearchRules,
  rateRules,
};
