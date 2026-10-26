/**
 * Builds the Mongo filter for browsing listings — shared by GET /api/listings
 * and the saved-search alert job so "matches your saved search" means exactly
 * what the user would see by applying the same filters in the app.
 */

const escapeRegex = (s) => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const buildListingFilter = ({
  category,
  condition,
  campus,
  minPrice,
  maxPrice,
  search,
  hideAiGenerated,
} = {}) => {
  // Only show active and pending to public
  const filter = { status: { $in: ['active', 'pending'] } };

  if (category)  filter.category  = category;
  if (condition) filter.condition = condition;
  if (campus)    filter.campus    = campus;
  if (hideAiGenerated === true || hideAiGenerated === 'true') {
    filter.isAiGenerated = { $ne: true };
  }
  if (search) {
    const re = new RegExp(escapeRegex(search), 'i');
    filter.$or = [{ title: re }, { description: re }];
  }
  if (minPrice != null && minPrice !== '' || maxPrice != null && maxPrice !== '') {
    filter.price = {};
    if (minPrice != null && minPrice !== '') filter.price.$gte = parseFloat(minPrice);
    if (maxPrice != null && maxPrice !== '') filter.price.$lte = parseFloat(maxPrice);
  }

  return filter;
};

module.exports = { buildListingFilter };
