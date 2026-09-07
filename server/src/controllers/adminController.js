const User    = require('../models/User');
const Listing = require('../models/Listing');
const Thread  = require('../models/Thread');
const Message = require('../models/Message');
const { successResponse, errorResponse } = require('../utils/response');

// ── Users ─────────────────────────────────────────────────────────────────────

const getUsers = async (req, res) => {
  try {
    const { page = 1, limit = 20, search, role, isBlocked } = req.query;
    const filter = {};
    if (search)    filter.$or = [
      { name:  new RegExp(search, 'i') },
      { email: new RegExp(search, 'i') },
    ];
    if (role)      filter.role      = role;
    if (isBlocked !== undefined) filter.isBlocked = isBlocked === 'true';

    const skip  = (parseInt(page) - 1) * parseInt(limit);
    const total = await User.countDocuments(filter);
    const users = await User.find(filter)
      .select('-passwordHash')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    return successResponse(res, {
      users,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), totalPages: Math.ceil(total / parseInt(limit)) },
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

const updateUser = async (req, res) => {
  try {
    const { name, email, role, isBlocked, isVerifiedStudent, isEmailConfirmed } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) return errorResponse(res, 'User not found', 404);

    // Prevent admin from accidentally demoting themselves
    if (String(user._id) === String(req.user._id) && role && role !== 'admin') {
      return errorResponse(res, 'Cannot change your own admin role', 400);
    }

    if (name  !== undefined) user.name  = name;
    if (email !== undefined) user.email = email;
    if (role  !== undefined) user.role  = role;
    if (isBlocked          !== undefined) user.isBlocked          = isBlocked;
    if (isVerifiedStudent  !== undefined) user.isVerifiedStudent  = isVerifiedStudent;
    if (isEmailConfirmed   !== undefined) user.isEmailConfirmed   = isEmailConfirmed;

    await user.save();
    return successResponse(res, { user: user.toPublicProfile() }, 'User updated');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

const deleteUser = async (req, res) => {
  try {
    if (String(req.params.id) === String(req.user._id)) {
      return errorResponse(res, 'Cannot delete your own admin account', 400);
    }

    const target = await User.findById(req.params.id);
    if (!target) return errorResponse(res, 'User not found', 404);

    // Admin accounts can never be deleted, even by another admin
    if (target.role === 'admin') {
      return errorResponse(res, 'Admin accounts cannot be deleted', 403);
    }

    await target.deleteOne();

    // Cascade: set their listings to offMarket
    await Listing.updateMany({ owner: req.params.id }, { status: 'offMarket' });

    return successResponse(res, null, 'User deleted');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── Listings ──────────────────────────────────────────────────────────────────

const getAllListings = async (req, res) => {
  try {
    const { page = 1, limit = 20, status, search } = req.query;
    const filter = {};
    if (status) filter.status = status;
    if (search) filter.$or = [
      { title:       new RegExp(search, 'i') },
      { description: new RegExp(search, 'i') },
      { category:    new RegExp(search, 'i') },
    ];

    const skip  = (parseInt(page) - 1) * parseInt(limit);
    const total = await Listing.countDocuments(filter);
    const listings = await Listing.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate('owner', 'name email');

    return successResponse(res, {
      listings,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), totalPages: Math.ceil(total / parseInt(limit)) },
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

const reactivateListing = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    listing.status = 'active';
    const expiry   = new Date();
    expiry.setDate(expiry.getDate() + 90);
    listing.expiresAt = expiry;
    await listing.save();

    // Update thread snapshots
    await Thread.updateMany({ listing: listing._id }, { 'listingSnapshot.status': 'active' });

    return successResponse(res, { listing }, 'Listing reactivated — expiry reset to 90 days');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PATCH /api/admin/listings/:id/boost ───────────────────────────────────────
// Toggles a listing to the top of search results. Free for now — the fee-based
// flow to let sellers pay to boost their own listing lands later; this is the
// manual admin control in the meantime.
const toggleBoost = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    const isBoosted = listing.boostedUntil && new Date(listing.boostedUntil) > new Date();

    if (isBoosted) {
      listing.boostedUntil = null;
    } else {
      const until = new Date();
      until.setDate(until.getDate() + 30);
      listing.boostedUntil = until;
    }

    await listing.save();
    return successResponse(
      res,
      { listing },
      isBoosted ? 'Boost removed' : 'Listing boosted for 30 days'
    );
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

const adminDeleteListing = async (req, res) => {
  try {
    const listing = await Listing.findByIdAndDelete(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);
    await User.updateMany({ favorites: listing._id }, { $pull: { favorites: listing._id } });
    return successResponse(res, null, 'Listing permanently deleted');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── Threads (moderation) ──────────────────────────────────────────────────────

const getAllThreads = async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip  = (parseInt(page) - 1) * parseInt(limit);
    const total = await Thread.countDocuments();
    const threads = await Thread.find()
      .sort({ lastMessageAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .populate('participants', 'name email')
      .populate('listing', 'title');

    return successResponse(res, {
      threads,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), totalPages: Math.ceil(total / parseInt(limit)) },
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/admin/stats ───────────────────────────────────────────────────────
const getStats = async (req, res) => {
  try {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const [
      totalUsers, verifiedStudents, blockedUsers, activeLast7Days, newLast7Days,
      totalListings, activeListings, pendingListings, soldListings, boostedListings,
      totalThreads, totalMessages,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ isVerifiedStudent: true }),
      User.countDocuments({ isBlocked: true }),
      User.countDocuments({ lastActiveAt: { $gte: sevenDaysAgo } }),
      User.countDocuments({ createdAt: { $gte: sevenDaysAgo } }),
      Listing.countDocuments(),
      Listing.countDocuments({ status: 'active' }),
      Listing.countDocuments({ status: 'pending' }),
      Listing.countDocuments({ status: 'offMarket' }),
      Listing.countDocuments({ boostedUntil: { $gt: new Date() } }),
      Thread.countDocuments(),
      Message.countDocuments(),
    ]);

    return successResponse(res, {
      users: {
        total: totalUsers,
        verifiedStudents,
        blocked: blockedUsers,
        activeLast7Days,
        newLast7Days,
      },
      listings: {
        total: totalListings,
        active: activeListings,
        pending: pendingListings,
        sold: soldListings,
        boosted: boostedListings,
      },
      chat: {
        threads: totalThreads,
        messages: totalMessages,
      },
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

module.exports = {
  getUsers, updateUser, deleteUser,
  getAllListings, reactivateListing, adminDeleteListing, toggleBoost,
  getAllThreads,
  getStats,
};
