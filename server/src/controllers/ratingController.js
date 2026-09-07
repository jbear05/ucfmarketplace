const Rating = require('../models/Rating');
const { successResponse, errorResponse } = require('../utils/response');

// ── GET /api/ratings/user/:id ──────────────────────────────────────────────────
// Public — the reviews shown on a seller/buyer's profile.
const getUserRatings = async (req, res) => {
  try {
    const ratings = await Rating.find({ toUser: req.params.id })
      .sort({ createdAt: -1 })
      .populate('fromUser', 'name')
      .lean();

    return successResponse(res, { ratings });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

module.exports = { getUserRatings };
