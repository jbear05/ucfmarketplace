const mongoose = require('mongoose');

const threadSchema = new mongoose.Schema(
  {
    listing: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'Listing',
    },

    // Always exactly [inquirerId, listerId]
    participants: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref:  'User',
      },
    ],

    // Snapshot at thread creation — survives listing deletion/expiry
    listingSnapshot: {
      title:     String,
      mainImage: String,
      price:     Number,
      status:    String, // updated when listing status changes
    },

    // Either party can block — blocks new messages from both sides
    blockedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref:  'User',
      },
    ],

    // Soft delete per user — both must delete for thread to be truly gone
    deletedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref:  'User',
      },
    ],

    // Preview shown in thread list
    lastMessage:   { type: String, default: '' },
    lastMessageAt: { type: Date,   default: Date.now },

    // ── Meetup arrangement ────────────────────────────────────────────────────
    // Buyer and seller use the map to agree on a public spot + time to exchange
    // the item and complete payment in person.
    meetup: {
      location: {
        type: {
          type:    String,
          enum:    ['Point'],
          default: 'Point',
        },
        coordinates: [Number], // [longitude, latitude]
      },
      address:     String, // human-readable label, e.g. "Starbucks — Student Union"
      scheduledAt: Date,
      proposedBy:  { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      status: {
        type:    String,
        enum:    ['none', 'proposed', 'confirmed', 'completed', 'cancelled'],
        default: 'none',
      },
      // Both participants must confirm for status to become 'completed'
      confirmedBy: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref:  'User',
        },
      ],
    },
  },
  {
    timestamps: true,
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
threadSchema.index({ participants: 1 });               // fetch user's threads
threadSchema.index({ listing: 1, participants: 1 });   // unique thread per pair
threadSchema.index({ lastMessageAt: -1 });             // sort threads by recent

module.exports = mongoose.model('Thread', threadSchema);
