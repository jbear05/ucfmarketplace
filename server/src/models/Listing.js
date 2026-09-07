const mongoose = require('mongoose');

const CATEGORIES = [
  'Textbooks', 'Electronics', 'Furniture', 'Clothing',
  'Dorm & Home', 'Tickets & Events', 'Vehicles', 'Other',
];

const CONDITIONS = ['New', 'Like New', 'Good', 'Fair', 'Poor'];

const listingSchema = new mongoose.Schema(
  {
    owner: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },

    // ── Core info ─────────────────────────────────────────────────────────────
    title: {
      type:      String,
      required:  [true, 'Title is required'],
      trim:      true,
      maxlength: [100, 'Title cannot exceed 100 characters'],
    },
    description: {
      type:    String,
      trim:    true,
      maxlength: [2000, 'Description cannot exceed 2000 characters'],
    },
    price: {
      type:     Number,
      required: [true, 'Price is required'],
      min:      [0, 'Price cannot be negative'],
    },
    category: {
      type:     String,
      required: [true, 'Category is required'],
      enum:     CATEGORIES,
    },
    condition: {
      type:     String,
      required: [true, 'Condition is required'],
      enum:     CONDITIONS,
    },

    // ── Meetup area ───────────────────────────────────────────────────────────
    // A general public area, not an exact address — e.g. "Near the Student Union"
    // or "Knights Plaza". Geocoded (approximately) so it can show as a map pin.
    // The exact meeting spot/time is arranged per-conversation on the Thread.
    meetupArea: {
      type:     String,
      required: [true, 'A general meetup area is required'],
      trim:     true,
    },

    // GeoJSON point — auto-populated from meetupArea via Nominatim geocoding
    coordinates: {
      type: {
        type:   String,
        enum:   ['Point'],
        default: 'Point',
      },
      coordinates: {
        type:    [Number], // [longitude, latitude] — GeoJSON order
        default: [0, 0],
      },
    },

    // ── Images ────────────────────────────────────────────────────────────────
    // Array of Cloudinary URLs. First image is the card thumbnail.
    images: {
      type:     [String],
      validate: {
        validator: (arr) => arr.length >= 1,
        message:   'At least one image is required',
      },
    },

    // ── Social ────────────────────────────────────────────────────────────────
    // Incremented/decremented when users favorite/unfavorite
    favoriteCount: {
      type:    Number,
      default: 0,
      min:     0,
    },

    // ── Status lifecycle ──────────────────────────────────────────────────────
    // active   — visible to all, searchable
    // pending  — visible with "Meetup Scheduled" banner, set once a meetup is confirmed
    // offMarket — sold (both parties confirmed exchange), expired (auto), or admin action
    //             only admin can set back to active
    status: {
      type:    String,
      enum:    ['active', 'pending', 'offMarket'],
      default: 'active',
    },

    // ── Monetization (future — schema ready now) ──────────────────────────────
    // If boostedUntil is in the future, listing sorts to top
    boostedUntil: {
      type:    Date,
      default: null,
    },

    // ── Expiry ────────────────────────────────────────────────────────────────
    // Set to createdAt + 90 days on create. Cron job checks daily.
    expiresAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
listingSchema.index({ coordinates: '2dsphere' });          // geo queries
listingSchema.index({ status: 1, createdAt: -1 });         // default sort
listingSchema.index({ status: 1, category: 1 });           // category filter
listingSchema.index({ owner: 1 });                         // my listings
listingSchema.index({ expiresAt: 1 });                     // cron expiry check
listingSchema.index({ boostedUntil: 1, createdAt: -1 });   // boosted sort

// ── Pre-save: set expiresAt on first create ───────────────────────────────────
listingSchema.pre('save', function (next) {
  if (this.isNew && !this.expiresAt) {
    const expiry = new Date();
    expiry.setDate(expiry.getDate() + 90); // 90 days from now
    this.expiresAt = expiry;
  }
  next();
});

// ── Virtual: is this listing currently boosted? ───────────────────────────────
listingSchema.virtual('isBoosted').get(function () {
  return this.boostedUntil && this.boostedUntil > new Date();
});

listingSchema.statics.CATEGORIES = CATEGORIES;
listingSchema.statics.CONDITIONS = CONDITIONS;

module.exports = mongoose.model('Listing', listingSchema);
