const { v4: uuidv4 }           = require('uuid');
const User                     = require('../models/User');
const { generateToken }        = require('../middleware/auth');
const { successResponse, errorResponse } = require('../utils/response');
const {
  sendVerificationEmail,
  sendPasswordResetEmail,
} = require('../utils/email');
const { renderMessagePage, renderResetPasswordForm } = require('../utils/htmlPage');

// Verification/reset links are tapped straight from an email in a browser —
// there's no separate web client in this project, so the API renders a small
// HTML page itself for those requests instead of returning raw JSON.
const wantsHtml = (req) => req.accepts(['html', 'json']) === 'html';

// ── POST /api/auth/register ───────────────────────────────────────────────────
const register = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    // Check duplicate email
    const existing = await User.findOne({ email });
    if (existing) {
      return errorResponse(res, 'An account with this email already exists', 409);
    }

    // Auto-detect verified student via .edu email
    const isVerifiedStudent = email.toLowerCase().endsWith('.edu');

    // Generate email confirmation token
    const emailConfirmToken = uuidv4();

    // Create user — password goes into passwordHash, pre-save hook hashes it
    const user = await User.create({
      name,
      email,
      passwordHash:       password, // pre-save hook hashes this
      isVerifiedStudent,
      emailConfirmToken,
      // Auto-promote if email matches ADMIN_EMAIL env
      role: email.toLowerCase() === process.env.ADMIN_EMAIL?.toLowerCase()
        ? 'admin'
        : 'user',
    });

    // Send verification email (don't block response on failure)
    try {
      await sendVerificationEmail(email, name, emailConfirmToken);
    } catch (emailErr) {
      console.error('Verification email failed:', emailErr.message);
      // Don't fail registration if email fails — log and continue
    }

    return successResponse(
      res,
      {
        message: isVerifiedStudent
          ? 'Account created! Check your email to verify. Your .edu email gives you a Verified Student badge.'
          : 'Account created! Check your email to verify your account.',
      },
      'Registration successful',
      201
    );
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/auth/verify/:token ───────────────────────────────────────────────
const verifyEmail = async (req, res) => {
  try {
    const { token } = req.params;

    const user = await User.findOne({ emailConfirmToken: token }).select(
      '+emailConfirmToken'
    );

    if (!user) {
      if (wantsHtml(req)) {
        return res.status(400).send(renderMessagePage({
          heading: 'Link expired',
          message: 'This verification link is invalid or has already been used. Try registering again or requesting a new link from the app.',
          isError: true,
        }));
      }
      return errorResponse(res, 'Invalid or expired verification link', 400);
    }

    user.isEmailConfirmed  = true;
    user.emailConfirmToken = undefined; // clear token after use
    await user.save();

    // Generate JWT so user is logged in immediately after verification
    const jwt = generateToken(user._id);

    if (wantsHtml(req)) {
      return res.send(renderMessagePage({
        heading: 'Email verified! 🎉',
        message: 'Your KnightMarket account is ready. Head back to the app and log in.',
      }));
    }

    return successResponse(
      res,
      { token: jwt, user: user.toPublicProfile() },
      'Email verified! Welcome to KnightMarket.'
    );
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/auth/login ──────────────────────────────────────────────────────
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Select passwordHash explicitly (hidden by default)
    const user = await User.findOne({ email }).select(
      '+passwordHash +isEmailConfirmed +isBlocked'
    );

    if (!user) {
      // Generic message — don't reveal whether email exists
      return errorResponse(res, 'Invalid email or password', 401);
    }

    if (user.isBlocked) {
      return errorResponse(res, 'Your account has been suspended', 403);
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return errorResponse(res, 'Invalid email or password', 401);
    }

    if (!user.isEmailConfirmed) {
      return errorResponse(
        res,
        'Please verify your email first. Check your inbox for the verification link.',
        403
      );
    }

    user.lastActiveAt = new Date();
    await user.save();

    const token = generateToken(user._id);

    return successResponse(
      res,
      { token, user: user.toPublicProfile() },
      `Welcome back, ${user.name}!`
    );
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/auth/me ──────────────────────────────────────────────────────────
const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).populate('favorites');
    return successResponse(res, user.toPublicProfile());
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

const updateMe = async (req, res) => {
  try {
    const { name } = req.body;
    const updates = {};
    if (name && name.trim()) updates.name = name.trim();
    const user = await User.findByIdAndUpdate(req.user._id, updates, { new: true }).populate('favorites');
    return successResponse(res, { user: user.toPublicProfile() });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/auth/forgot-password ───────────────────────────────────────────
const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });

    // Always return success — don't reveal if email is registered
    if (!user) {
      return successResponse(
        res,
        null,
        'If an account with that email exists, a reset link has been sent.'
      );
    }

    const resetToken  = uuidv4();
    const resetExpiry = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    user.passwordResetToken  = resetToken;
    user.passwordResetExpiry = resetExpiry;
    await user.save();

    try {
      await sendPasswordResetEmail(email, user.name, resetToken);
    } catch (emailErr) {
      console.error('Reset email failed:', emailErr.message);
    }

    return successResponse(
      res,
      null,
      'If an account with that email exists, a reset link has been sent.'
    );
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/auth/reset-password/:token ───────────────────────────────────────
// Renders the form the "Reset My Password" email link opens.
const showResetPasswordForm = (req, res) => {
  res.send(renderResetPasswordForm({ token: req.params.token }));
};

// ── POST /api/auth/reset-password/:token ─────────────────────────────────────
const resetPassword = async (req, res) => {
  try {
    const { token }    = req.params;
    const { password } = req.body;

    const user = await User.findOne({
      passwordResetToken:  token,
      passwordResetExpiry: { $gt: new Date() }, // not expired
    }).select('+passwordResetToken +passwordResetExpiry');

    if (!user) {
      if (wantsHtml(req)) {
        return res.status(400).send(renderMessagePage({
          heading: 'Link expired',
          message: 'This reset link is invalid or has expired. Request a new one from the app.',
          isError: true,
        }));
      }
      return errorResponse(res, 'Reset link is invalid or has expired', 400);
    }

    user.passwordHash        = password; // pre-save hook re-hashes
    user.passwordResetToken  = undefined;
    user.passwordResetExpiry = undefined;
    await user.save();

    if (wantsHtml(req)) {
      return res.send(renderMessagePage({
        heading: 'Password reset! 🎉',
        message: 'Head back to the KnightMarket app and log in with your new password.',
      }));
    }

    return successResponse(res, null, 'Password reset successful — please log in.');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/auth/resend-verification ───────────────────────────────────────
const resendVerification = async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email }).select('+emailConfirmToken +isEmailConfirmed');

    if (!user || user.isEmailConfirmed) {
      // Don't reveal account status
      return successResponse(res, null, 'If your email is pending verification, a new link has been sent.');
    }

    // Generate fresh token
    user.emailConfirmToken = uuidv4();
    await user.save();

    await sendVerificationEmail(email, user.name, user.emailConfirmToken);

    return successResponse(res, null, 'Verification email resent. Check your inbox.');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

module.exports = {
  updateMe,
  register,
  verifyEmail,
  login,
  getMe,
  forgotPassword,
  showResetPasswordForm,
  resetPassword,
  resendVerification,
};
