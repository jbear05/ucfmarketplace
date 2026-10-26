const mongoose = require('mongoose');

const CATEGORIES = [
  'Textbooks', 'Electronics', 'Furniture', 'Clothing',
  'Dorm & Home', 'Tickets & Events', 'Vehicles', 'Other',
];

const CONDITIONS = ['New', 'Like New', 'Good', 'Fair', 'Poor'];

// Must match kListingCampuses in mobile/lib/models/listing.dart
const CAMPUSES = ['Main Campus', 'Downtown', 'Rosen', 'Lake Nona'];

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

    // ── Location ──────────────────────────────────────────────────────────────
    // Which UCF campus the seller is on. The exact meeting spot/time is
    // arranged per-conversation on the Thread from a curated list of spots.
    campus: {
      type:    String,
      enum:    CAMPUSES,
      default: 'Main Campus',
    },

    // Legacy free-text area (e.g. "Near the Student Union") from before
    // campuses existed. New listings set it to the campus name.
    meetupArea: {
      type: String,
      trim: true,
    },

    // GeoJSON point — the campus center for new listings, or the geocoded
    // meetupArea for older ones
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

    // Disclosure for AI-generated artwork or prints — buyers can filter these out
    isAiGenerated: {
      type:    Boolean,
      default: false,
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

    // ── Price-drop alerts ─────────────────────────────────────────────────────
    // Set when the owner lowers the price; the daily alert job emails users
    // who favorited the listing, then clears priceDroppedAt.
    previousPrice: {
      type:    Number,
      default: null,
    },
    priceDroppedAt: {
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
listingSchema.index({ priceDroppedAt: 1 });                // price-drop alert job

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
listingSchema.statics.CAMPUSES   = CAMPUSES;

module.exports = mongoose.model('Listing', listingSchema);
