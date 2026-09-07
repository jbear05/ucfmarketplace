const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    name: {
      type:     String,
      required: [true, 'Name is required'],
      trim:     true,
      maxlength: [60, 'Name cannot exceed 60 characters'],
    },
    email: {
      type:      String,
      required:  [true, 'Email is required'],
      unique:    true,
      lowercase: true,
      trim:      true,
      match:     [/^\S+@\S+\.\S+$/, 'Please enter a valid email'],
    },
    passwordHash: {
      type:     String,
      required: true,
      select:   false, // never returned in queries by default
    },

    // Verified student badge — auto-set on register if email ends in .edu
    isVerifiedStudent: {
      type:    Boolean,
      default: false,
    },

    // Email confirmation — must confirm before first login
    isEmailConfirmed: {
      type:    Boolean,
      default: false,
    },
    emailConfirmToken: {
      type:   String,
      select: false,
    },

    // Password reset
    passwordResetToken: {
      type:   String,
      select: false,
    },
    passwordResetExpiry: {
      type:   Date,
      select: false,
    },

    // Role — only admin can be set manually or via ADMIN_EMAIL env
    role: {
      type:    String,
      enum:    ['user', 'admin'],
      default: 'user',
    },

    // Favorites — array of Listing ObjectIds
    favorites: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref:  'Listing',
      },
    ],

    // Blocked threads — user-level block list
    blockedThreads: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref:  'Thread',
      },
    ],

    // Admin can block an account entirely
    isBlocked: {
      type:    Boolean,
      default: false,
    },

    // Bumped on login and on every authenticated request — powers the
    // admin "last activity" column.
    lastActiveAt: {
      type:    Date,
      default: Date.now,
    },

    // Denormalized rating summary — recomputed whenever a new Rating is
    // created for this user. Avoids aggregating the ratings collection on
    // every listing/profile fetch.
    ratingAvg: {
      type:    Number,
      default: 0,
    },
    ratingCount: {
      type:    Number,
      default: 0,
    },
  },
  {
    timestamps: true, // adds createdAt, updatedAt automatically
  }
);


// ── Pre-save hook: hash password before saving ────────────────────────────────
userSchema.pre('save', async function (next) {
  // Only hash if password field was modified (avoids re-hashing on other updates)
  if (!this.isModified('passwordHash')) return next();
  const salt       = await bcrypt.genSalt(12);
  this.passwordHash = await bcrypt.hash(this.passwordHash, salt);
  next();
});

// ── Instance method: compare password ────────────────────────────────────────
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.passwordHash);
};

// ── Instance method: safe public profile (no secrets) ────────────────────────
userSchema.methods.toPublicProfile = function () {
  return {
    _id:               this._id,
    name:              this.name,
    email:             this.email,
    isVerifiedStudent: this.isVerifiedStudent,
    role:              this.role,
    favorites:         this.favorites,
    ratingAvg:         this.ratingAvg,
    ratingCount:       this.ratingCount,
    createdAt:         this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);
