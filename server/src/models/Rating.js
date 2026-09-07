const mongoose = require('mongoose');

// A rating left by one side of a completed exchange about the other —
// builds trust for future buyers/sellers browsing a profile or listing.
const ratingSchema = new mongoose.Schema(
  {
    thread: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'Thread',
      required: true,
    },
    fromUser: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },
    toUser: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },
    score: {
      type:     Number,
      required: [true, 'A rating score is required'],
      min:      1,
      max:      5,
    },
    feedback: {
      type:      String,
      trim:      true,
      maxlength: [500, 'Feedback cannot exceed 500 characters'],
    },
  },
  { timestamps: true }
);

// One rating per rater per completed transaction
ratingSchema.index({ thread: 1, fromUser: 1 }, { unique: true });
ratingSchema.index({ toUser: 1, createdAt: -1 }); // fetch a user's received ratings

module.exports = mongoose.model('Rating', ratingSchema);
