const mongoose = require('mongoose');

// A user's saved set of browse filters. The daily alert job emails the user
// about listings created since lastNotifiedAt that match these filters.
const savedSearchSchema = new mongoose.Schema(
  {
    user: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },
    label: {
      type:      String,
      required:  [true, 'A name is required'],
      trim:      true,
      maxlength: [60, 'Name cannot exceed 60 characters'],
    },
    // Same keys as the GET /api/listings query (minus sorting)
    filters: {
      search:          String,
      category:        String,
      condition:       String,
      campus:          String,
      minPrice:        Number,
      maxPrice:        Number,
      hideAiGenerated: { type: Boolean, default: false },
    },
    lastNotifiedAt: {
      type:    Date,
      default: Date.now, // only listings created after saving count as "new"
    },
  },
  {
    timestamps: true,
  }
);

savedSearchSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('SavedSearch', savedSearchSchema);
