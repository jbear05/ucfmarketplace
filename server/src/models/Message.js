const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    thread: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'Thread',
      required: true,
    },
    sender: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },
    body: {
      type:      String,
      required:  [true, 'Message body is required'],
      trim:      true,
      maxlength: [2000, 'Message cannot exceed 2000 characters'],
    },
    // Track who has read this message for unread count calculation
    readBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref:  'User',
      },
    ],
  },
  {
    timestamps: true,
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
messageSchema.index({ thread: 1, createdAt: 1 }); // load messages in order
messageSchema.index({ thread: 1, readBy: 1 });     // unread count queries

module.exports = mongoose.model('Message', messageSchema);
