const Thread  = require('../models/Thread');
const Message = require('../models/Message');
const Listing = require('../models/Listing');
const Rating  = require('../models/Rating');
const User    = require('../models/User');
const { successResponse, errorResponse } = require('../utils/response');

// ── POST /api/threads ─────────────────────────────────────────────────────────
// Start a new thread between an inquirer and a lister for a listing
const createThread = async (req, res) => {
  try {
    const { listingId } = req.body;

    const listing = await Listing.findById(listingId).populate('owner', 'name');
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    // Cannot message yourself
    if (String(listing.owner._id) === String(req.user._id)) {
      return errorResponse(res, 'You cannot message yourself about your own listing', 400);
    }

    // Check if thread already exists between this pair for this listing
    const existing = await Thread.findOne({
      listing:      listingId,
      participants: { $all: [req.user._id, listing.owner._id] },
    });

    if (existing) {
      return successResponse(res, { thread: existing }, 'Thread already exists');
    }

    // Snapshot listing data — survives listing deletion/expiry
    const thread = await Thread.create({
      listing:     listingId,
      participants: [req.user._id, listing.owner._id],
      listingSnapshot: {
        title:     listing.title,
        mainImage: listing.images[0] || '',
        price:     listing.price,
        status:    listing.status,
      },
    });

    await thread.populate('participants', 'name isVerifiedStudent ratingAvg ratingCount');

    return successResponse(res, { thread }, 'Conversation started', 201);
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/threads/contact-admin ───────────────────────────────────────────
// Starts (or reuses) a support conversation between the current user and an
// admin — no listing involved. Reuses the normal thread/message system so it
// shows up in both inboxes exactly like any other conversation.
const contactAdmin = async (req, res) => {
  try {
    const { message } = req.body;
    if (!message || !message.trim()) {
      return errorResponse(res, 'Message cannot be empty', 400);
    }

    const admin = await User.findOne({ role: 'admin' });
    if (!admin) return errorResponse(res, 'No admin account is available right now', 503);

    if (String(admin._id) === String(req.user._id)) {
      return errorResponse(res, 'You are already an admin', 400);
    }

    let thread = await Thread.findOne({
      listing:      null,
      participants: { $all: [req.user._id, admin._id], $size: 2 },
    });

    if (!thread) {
      thread = await Thread.create({ participants: [req.user._id, admin._id] });
    }

    const chatMessage = await Message.create({
      thread: thread._id,
      sender: req.user._id,
      body:   message.trim().substring(0, 2000),
      readBy: [req.user._id],
    });

    thread.lastMessage   = chatMessage.body.substring(0, 80);
    thread.lastMessageAt = new Date();
    await thread.save();
    await thread.populate('participants', 'name isVerifiedStudent ratingAvg ratingCount');

    const io = req.app.get('io');
    if (io) {
      io.to(`user:${admin._id}`).emit('newMessage', { threadId: thread._id, message: chatMessage });
      io.to(`user:${admin._id}`).emit('unreadCountUpdate');
    }

    return successResponse(res, { thread }, 'Message sent to admin', 201);
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/threads ──────────────────────────────────────────────────────────
// All threads for the current user — sorted by most recent message
const getThreads = async (req, res) => {
  try {
    const threads = await Thread.find({
      participants: req.user._id,
      deletedBy:    { $ne: req.user._id }, // hide threads this user deleted
    })
      .sort({ lastMessageAt: -1 })
      .populate('participants', 'name isVerifiedStudent ratingAvg ratingCount')
      .lean();

    // Count unread messages per thread
    const threadsWithUnread = await Promise.all(
      threads.map(async (thread) => {
        const unreadCount = await Message.countDocuments({
          thread: thread._id,
          sender: { $ne: req.user._id }, // messages not sent by me
          readBy: { $ne: req.user._id }, // that I haven't read
        });

        const isBlocked = thread.blockedBy?.map(String).includes(String(req.user._id));

        return { ...thread, unreadCount, isBlocked };
      })
    );

    // Total unread across all threads (for navbar badge)
    const totalUnread = threadsWithUnread.reduce((sum, t) => sum + t.unreadCount, 0);

    return successResponse(res, { threads: threadsWithUnread, totalUnread });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/threads/:id/messages ─────────────────────────────────────────────
const getMessages = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);

    // Only participants can read messages
    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }

    const messages = await Message.find({ thread: thread._id })
      .sort({ createdAt: 1 })
      .populate('sender', 'name isVerifiedStudent')
      .lean();

    // Mark all unread messages as read by current user
    await Message.updateMany(
      {
        thread: thread._id,
        sender: { $ne: req.user._id },
        readBy: { $ne: req.user._id },
      },
      { $addToSet: { readBy: req.user._id } }
    );

    // Let the client know whether this user still needs to rate this exchange
    let hasRated = false;
    if (thread.meetup?.status === 'completed') {
      hasRated = !!(await Rating.exists({ thread: thread._id, fromUser: req.user._id }));
    }

    return successResponse(res, { messages, thread, hasRated });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/threads/:id/messages ────────────────────────────────────────────
const sendMessage = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);

    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }

    // Block check — if either party has blocked, no new messages
    if (thread.blockedBy?.length > 0) {
      return errorResponse(res, 'This conversation has been blocked', 403);
    }

    const message = await Message.create({
      thread: thread._id,
      sender: req.user._id,
      body:   req.body.body,
      readBy: [req.user._id], // sender has already "read" their own message
    });

    // Update thread preview
    thread.lastMessage   = req.body.body.substring(0, 80);
    thread.lastMessageAt = new Date();
    await thread.save();

    await message.populate('sender', 'name isVerifiedStudent');

    // Emit via Socket.io to the other participant
    const io        = req.app.get('io');
    const recipient = thread.participants.find(
      (p) => String(p) !== String(req.user._id)
    );
    if (io && recipient) {
      io.to(`user:${recipient}`).emit('newMessage', {
        threadId: thread._id,
        message,
      });
      io.to(`user:${recipient}`).emit('unreadCountUpdate');
    }

    return successResponse(res, { message }, 'Message sent', 201);
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PATCH /api/threads/:id/block ──────────────────────────────────────────────
const blockThread = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);
    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }

    const alreadyBlocked = thread.blockedBy.map(String).includes(String(req.user._id));
    if (alreadyBlocked) {
      // Unblock
      thread.blockedBy = thread.blockedBy.filter(
        (id) => String(id) !== String(req.user._id)
      );
    } else {
      thread.blockedBy.push(req.user._id);
    }
    await thread.save();

    return successResponse(
      res,
      { blocked: !alreadyBlocked },
      alreadyBlocked ? 'Thread unblocked' : 'Thread blocked'
    );
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PATCH /api/threads/:id/delete ─────────────────────────────────────────────
// Soft delete — hides thread from this user only. Truly deleted when both delete.
const deleteThread = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);
    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }

    if (!thread.deletedBy.map(String).includes(String(req.user._id))) {
      thread.deletedBy.push(req.user._id);
    }

    // Both participants deleted — remove thread and messages entirely
    if (thread.deletedBy.length === thread.participants.length) {
      await Message.deleteMany({ thread: thread._id });
      await thread.deleteOne();
      return successResponse(res, null, 'Thread permanently deleted');
    }

    await thread.save();
    return successResponse(res, null, 'Thread removed from your inbox');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PATCH /api/threads/:id/meetup ─────────────────────────────────────────────
// Either participant proposes a public meetup spot + time to exchange the item
const proposeMeetup = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);
    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }
    if (thread.blockedBy?.length > 0) {
      return errorResponse(res, 'This conversation has been blocked', 403);
    }

    const { address, lat, lng, scheduledAt } = req.body;
    if (!address || lat === undefined || lng === undefined) {
      return errorResponse(res, 'A meetup address and location are required', 400);
    }

    thread.meetup = {
      location:    { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
      address,
      scheduledAt: scheduledAt ? new Date(scheduledAt) : undefined,
      proposedBy:  req.user._id,
      status:      'proposed',
      confirmedBy: [],
    };
    await thread.save();

    // Drop a system-style message into the thread so it shows in history
    const message = await Message.create({
      thread: thread._id,
      sender: req.user._id,
      body:   `📍 Proposed a meetup at ${address}${scheduledAt ? ` on ${new Date(scheduledAt).toLocaleString()}` : ''}`,
      readBy: [req.user._id],
    });
    thread.lastMessage   = message.body.substring(0, 80);
    thread.lastMessageAt = new Date();
    await thread.save();
    await message.populate('sender', 'name isVerifiedStudent');

    const io        = req.app.get('io');
    const recipient = thread.participants.find((p) => String(p) !== String(req.user._id));
    if (io && recipient) {
      io.to(`user:${recipient}`).emit('newMessage', { threadId: thread._id, message });
      io.to(`user:${recipient}`).emit('unreadCountUpdate');
      io.to(`user:${recipient}`).emit('meetupUpdate', { threadId: thread._id, meetup: thread.meetup });
    }

    return successResponse(res, { thread }, 'Meetup proposed');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PATCH /api/threads/:id/meetup/respond ─────────────────────────────────────
// The other participant confirms or either participant cancels the proposed meetup
const respondMeetup = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);
    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }
    if (!thread.meetup || thread.meetup.status === 'none') {
      return errorResponse(res, 'No meetup has been proposed', 400);
    }

    const { action } = req.body; // 'confirm' | 'cancel'
    if (!['confirm', 'cancel'].includes(action)) {
      return errorResponse(res, 'Invalid action', 400);
    }

    if (action === 'cancel') {
      thread.meetup.status = 'cancelled';
    } else {
      if (String(thread.meetup.proposedBy) === String(req.user._id)) {
        return errorResponse(res, 'Wait for the other person to confirm the meetup', 400);
      }
      thread.meetup.status = 'confirmed';

      // Mark the listing as pending (meetup scheduled) if it's still active
      const listing = await Listing.findById(thread.listing);
      if (listing && listing.status === 'active') {
        listing.status = 'pending';
        await listing.save();
        thread.listingSnapshot.status = 'pending';
      }
    }
    await thread.save();

    const io        = req.app.get('io');
    const recipient = thread.participants.find((p) => String(p) !== String(req.user._id));
    if (io && recipient) {
      io.to(`user:${recipient}`).emit('meetupUpdate', { threadId: thread._id, meetup: thread.meetup });
    }

    return successResponse(res, { thread }, `Meetup ${thread.meetup.status}`);
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PATCH /api/threads/:id/meetup/complete ────────────────────────────────────
// Each participant confirms in person that the item + payment were exchanged.
// Once both have confirmed, the listing is marked sold (offMarket).
const completeMeetup = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);
    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }
    if (!thread.meetup || thread.meetup.status !== 'confirmed') {
      return errorResponse(res, 'There is no confirmed meetup to complete', 400);
    }

    const already = thread.meetup.confirmedBy.map(String);
    if (!already.includes(String(req.user._id))) {
      thread.meetup.confirmedBy.push(req.user._id);
    }

    const allConfirmed = thread.participants.every((p) =>
      thread.meetup.confirmedBy.map(String).includes(String(p))
    );

    if (allConfirmed) {
      thread.meetup.status = 'completed';
      const listing = await Listing.findById(thread.listing);
      if (listing) {
        listing.status = 'offMarket';
        await listing.save();
      }
      thread.listingSnapshot.status = 'offMarket';
    }
    await thread.save();

    const io        = req.app.get('io');
    const recipient = thread.participants.find((p) => String(p) !== String(req.user._id));
    if (io && recipient) {
      io.to(`user:${recipient}`).emit('meetupUpdate', { threadId: thread._id, meetup: thread.meetup });
    }

    return successResponse(
      res,
      { thread },
      allConfirmed ? 'Exchange completed — listing marked as sold' : 'Waiting for the other person to confirm'
    );
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/threads/:id/rate ────────────────────────────────────────────────
// Either participant rates the other after a completed exchange — builds
// trust for future buyers/sellers browsing a profile or listing.
const rateThread = async (req, res) => {
  try {
    const thread = await Thread.findById(req.params.id);
    if (!thread) return errorResponse(res, 'Thread not found', 404);
    if (!thread.participants.map(String).includes(String(req.user._id))) {
      return errorResponse(res, 'Not authorized', 403);
    }
    if (thread.meetup?.status !== 'completed') {
      return errorResponse(res, 'You can only rate after the exchange is completed', 400);
    }

    const toUserId = thread.participants.find((p) => String(p) !== String(req.user._id));
    if (!toUserId) return errorResponse(res, 'No one to rate in this conversation', 400);

    const { score, feedback } = req.body;

    let rating;
    try {
      rating = await Rating.create({
        thread:   thread._id,
        fromUser: req.user._id,
        toUser:   toUserId,
        score,
        feedback,
      });
    } catch (err) {
      if (err.code === 11000) {
        return errorResponse(res, 'You already rated this transaction', 409);
      }
      throw err;
    }

    // Recompute the ratee's running average
    const toUser = await User.findById(toUserId);
    const newCount = toUser.ratingCount + 1;
    const newAvg   = (toUser.ratingAvg * toUser.ratingCount + score) / newCount;
    toUser.ratingCount = newCount;
    toUser.ratingAvg   = Math.round(newAvg * 10) / 10; // one decimal place
    await toUser.save();

    return successResponse(res, { rating }, 'Rating submitted — thanks!', 201);
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/threads/unread-count ─────────────────────────────────────────────
// Lightweight endpoint — navbar badge polls this
const getUnreadCount = async (req, res) => {
  try {
    const count = await Message.countDocuments({
      sender: { $ne: req.user._id },
      readBy: { $ne: req.user._id },
      thread: {
        $in: await Thread.find({
          participants: req.user._id,
          deletedBy: { $ne: req.user._id },
        }).distinct('_id'),
      },
    });
    return successResponse(res, { unreadCount: count });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

module.exports = {
  createThread,
  contactAdmin,
  getThreads,
  getMessages,
  sendMessage,
  blockThread,
  deleteThread,
  getUnreadCount,
  proposeMeetup,
  respondMeetup,
  completeMeetup,
  rateThread,
};
