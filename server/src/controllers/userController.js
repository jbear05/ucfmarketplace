const mongoose = require('mongoose');
const User     = require('../models/User');
const Listing  = require('../models/Listing');
const Thread   = require('../models/Thread');
const { successResponse, errorResponse } = require('../utils/response');

// ── GET /api/users/:id ────────────────────────────────────────────────────────
// Public seller profile: safe profile fields, completed-sale count, and the
// seller's currently active listings.
const getPublicProfile = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return errorResponse(res, 'User not found', 404);
    }
    const user = await User.findById(req.params.id);
    if (!user || user.isBlocked) return errorResponse(res, 'User not found', 404);

    const [listings, ownedIds] = await Promise.all([
      Listing.find({ owner: user._id, status: 'active' })
        .sort({ createdAt: -1 })
        .populate('owner', 'name isVerifiedStudent ratingAvg ratingCount avatarUrl')
        .lean(),
      Listing.find({ owner: user._id }).distinct('_id'),
    ]);

    // A sale = an exchange both sides marked complete on one of their listings
    const salesCount = await Thread.countDocuments({
      listing:         { $in: ownedIds },
      'meetup.status': 'completed',
    });

    return successResponse(res, {
      profile: { ...user.toSellerProfile(), salesCount },
      listings,
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

module.exports = { getPublicProfile };
