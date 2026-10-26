const SavedSearch = require('../models/SavedSearch');
const { successResponse, errorResponse } = require('../utils/response');

const MAX_SAVED_SEARCHES = 10;

// ── GET /api/saved-searches ───────────────────────────────────────────────────
const getSavedSearches = async (req, res) => {
  try {
    const savedSearches = await SavedSearch.find({ user: req.user._id })
      .sort({ createdAt: -1 })
      .lean();
    return successResponse(res, { savedSearches });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/saved-searches ──────────────────────────────────────────────────
const createSavedSearch = async (req, res) => {
  try {
    const count = await SavedSearch.countDocuments({ user: req.user._id });
    if (count >= MAX_SAVED_SEARCHES) {
      return errorResponse(res, `You can save up to ${MAX_SAVED_SEARCHES} searches — delete one first`, 400);
    }

    const { label, filters = {} } = req.body;
    const savedSearch = await SavedSearch.create({
      user: req.user._id,
      label,
      filters: {
        search:          filters.search,
        category:        filters.category,
        condition:       filters.condition,
        campus:          filters.campus,
        minPrice:        filters.minPrice,
        maxPrice:        filters.maxPrice,
        hideAiGenerated: filters.hideAiGenerated === true || filters.hideAiGenerated === 'true',
      },
    });

    return successResponse(res, { savedSearch }, 'Search saved', 201);
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── DELETE /api/saved-searches/:id ────────────────────────────────────────────
const deleteSavedSearch = async (req, res) => {
  try {
    const deleted = await SavedSearch.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!deleted) return errorResponse(res, 'Saved search not found', 404);
    return successResponse(res, null, 'Saved search deleted');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

module.exports = { getSavedSearches, createSavedSearch, deleteSavedSearch };
