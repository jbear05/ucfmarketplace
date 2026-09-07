const express = require('express');
const router  = express.Router();

const {
  register,
  verifyEmail,
  login,
  getMe,
  updateMe,
  forgotPassword,
  showResetPasswordForm,
  resetPassword,
  resendVerification,
} = require('../controllers/authController');

const { protect } = require('../middleware/auth');
const {
  registerRules,
  loginRules,
  forgotPasswordRules,
  resetPasswordRules,
  validate,
} = require('../middleware/validate');

// Public routes
router.post('/register',             registerRules,      validate, register);
router.get( '/verify/:token',                                      verifyEmail);
router.post('/login',                loginRules,         validate, login);
router.post('/forgot-password',      forgotPasswordRules, validate, forgotPassword);
router.get( '/reset-password/:token',                                showResetPasswordForm);
router.post('/reset-password/:token', resetPasswordRules, validate, resetPassword);
router.post('/resend-verification',  forgotPasswordRules, validate, resendVerification);

// Protected routes
router.get('/me',  protect, getMe);
router.put('/me',  protect, updateMe);

module.exports = router;
