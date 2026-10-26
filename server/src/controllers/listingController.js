const Listing    = require('../models/Listing');
const User       = require('../models/User');
const Thread     = require('../models/Thread');
const { CAMPUS_CENTERS, UCF_CAMPUS_CENTER } = require('../utils/geocode');
const { buildListingFilter }                 = require('../utils/listingFilter');
const { successResponse, errorResponse } = require('../utils/response');
const { cloudinary }                     = require('../config/cloudinary');

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Build the sort object for listing queries.
 * Boosted listings always float to top, then apply requested sort.
 */
const buildSort = (sortBy) => {
  // Boosted first (boostedUntil in future = 1, else = 0), then secondary sort
  const boostField = { boostedUntil: -1 }; // null sorts below dates in Mongo
  switch (sortBy) {
    case 'price_asc':  return { ...boostField, price: 1,  createdAt: -1 };
    case 'price_desc': return { ...boostField, price: -1, createdAt: -1 };
    default:            return { ...boostField, createdAt: -1 }; // newest first
  }
};

// ── GET /api/listings ─────────────────────────────────────────────────────────
const getListings = async (req, res) => {
  try {
    const { page = 1, limit = 12, sortBy, lat, lng } = req.query;

    const filter = buildListingFilter(req.query);
    const skip   = (parseInt(page) - 1) * parseInt(limit);
    const total  = await Listing.countDocuments(filter);

    // "Closest to me" — $near returns results ordered by distance, so it
    // replaces the normal sort. Without a location, fall back to newest.
    const userLat = parseFloat(lat);
    const userLng = parseFloat(lng);
    const byDistance = sortBy === 'closest' && Number.isFinite(userLat) && Number.isFinite(userLng);

    const query = byDistance
      ? Listing.find({
          ...filter,
          coordinates: {
            $near: { $geometry: { type: 'Point', coordinates: [userLng, userLat] } },
          },
        })
      : Listing.find(filter).sort(buildSort(sortBy));

    const listings = await query
      .skip(skip)
      .limit(parseInt(limit))
      .populate('owner', 'name isVerifiedStudent ratingAvg ratingCount avatarUrl')
      .lean();

    // If user is authenticated, mark which listings they've favorited
    let favoriteSet = new Set();
    if (req.user) {
      const user = await User.findById(req.user._id).select('favorites');
      favoriteSet = new Set(user.favorites.map(String));
    }

    const listingsWithMeta = listings.map((l) => ({
      ...l,
      isFavorited: favoriteSet.has(String(l._id)),
      isBoosted:   l.boostedUntil && new Date(l.boostedUntil) > new Date(),
      // Owner cannot favorite their own listing — flag for frontend
      isOwnListing: req.user ? String(l.owner._id) === String(req.user._id) : false,
    }));

    return successResponse(res, {
      listings: listingsWithMeta,
      pagination: {
        total,
        page:       parseInt(page),
        limit:      parseInt(limit),
        totalPages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/listings/mine ────────────────────────────────────────────────────
const getMyListings = async (req, res) => {
  try {
    // Returns ALL statuses including offMarket — lister can see their own archive
    const listings = await Listing.find({ owner: req.user._id })
      .sort({ createdAt: -1 })
      .lean();

    return successResponse(res, { listings });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/listings/:id ─────────────────────────────────────────────────────
const getListing = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id)
      .populate('owner', 'name isVerifiedStudent email ratingAvg ratingCount')
      .lean();

    if (!listing) {
      return errorResponse(res, 'Listing not found', 404);
    }

    // Non-admin users cannot see offMarket listings (unless they own it)
    const isOwner = req.user && String(listing.owner._id) === String(req.user._id);
    const isAdmin = req.user?.role === 'admin';

    if (listing.status === 'offMarket' && !isOwner && !isAdmin) {
      return errorResponse(res, 'This listing is no longer available', 404);
    }

    const isFavorited = req.user
      ? (await User.findById(req.user._id).select('favorites')).favorites
          .map(String)
          .includes(String(listing._id))
      : false;

    return successResponse(res, {
      ...listing,
      isFavorited,
      isOwnListing: isOwner,
      isBoosted: listing.boostedUntil && new Date(listing.boostedUntil) > new Date(),
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/listings ────────────────────────────────────────────────────────
const createListing = async (req, res) => {
  try {
    const { title, description, price, category, condition, campus, isAiGenerated } = req.body;

    // Collect uploaded image URLs from Cloudinary (via multer middleware)
    const images = req.files?.map((f) => f.path) || [];
    if (images.length === 0) {
      return errorResponse(res, 'At least one image is required', 400);
    }

    // Pin the listing at its campus — the exact spot is agreed in chat
    const coordinates = { type: 'Point', coordinates: CAMPUS_CENTERS[campus] || UCF_CAMPUS_CENTER };

    const listing = await Listing.create({
      owner: req.user._id,
      title,
      description,
      price: parseFloat(price),
      category,
      condition,
      campus,
      meetupArea: campus,
      isAiGenerated: isAiGenerated === true || isAiGenerated === 'true',
      coordinates,
      images,
    });

    await listing.populate('owner', 'name isVerifiedStudent ratingAvg ratingCount');

    return successResponse(res, { listing }, 'Listing created successfully', 201);
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PUT /api/listings/:id ─────────────────────────────────────────────────────
const updateListing = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    // Only owner or admin can edit
    const isOwner = String(listing.owner) === String(req.user._id);
    if (!isOwner && req.user.role !== 'admin') {
      return errorResponse(res, 'Not authorized to edit this listing', 403);
    }

    const oldPrice = listing.price;
    const allowed  = ['title', 'description', 'price', 'category', 'condition'];

    allowed.forEach((field) => {
      if (req.body[field] !== undefined) listing[field] = req.body[field];
    });
    if (req.body.isAiGenerated !== undefined) {
      listing.isAiGenerated = req.body.isAiGenerated === true || req.body.isAiGenerated === 'true';
    }

    // Moving campus moves the map pin
    if (req.body.campus !== undefined && req.body.campus !== listing.campus) {
      listing.campus      = req.body.campus;
      listing.meetupArea  = req.body.campus;
      listing.coordinates = { type: 'Point', coordinates: CAMPUS_CENTERS[listing.campus] || UCF_CAMPUS_CENTER };
    }

    // Record a price drop for the daily alert email to favoriters. Keep the
    // highest pre-drop price if it drops again before the job runs.
    if (listing.price < oldPrice) {
      if (!listing.priceDroppedAt) listing.previousPrice = oldPrice;
      listing.priceDroppedAt = new Date();
    }

    // Handle new images if uploaded
    if (req.files?.length > 0) {
      listing.images = [...listing.images, ...req.files.map((f) => f.path)];
    }

    await listing.save();
    return successResponse(res, { listing }, 'Listing updated');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── PATCH /api/listings/:id/status ───────────────────────────────────────────
// Owner can toggle: active ↔ pending
// Admin can set: active, pending, offMarket
const updateStatus = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    const isOwner = String(listing.owner) === String(req.user._id);
    const isAdmin = req.user.role === 'admin';

    if (!isOwner && !isAdmin) {
      return errorResponse(res, 'Not authorized', 403);
    }

    const { status } = req.body;

    // Validate status value
    if (!['active', 'pending', 'offMarket'].includes(status)) {
      return errorResponse(res, 'Invalid status value', 400);
    }

    // Admin reactivating an offMarket listing resets the expiry clock
    if (isAdmin && status === 'active' && listing.status === 'offMarket') {
      const expiry = new Date();
      expiry.setDate(expiry.getDate() + 90);
      listing.expiresAt = expiry;
    }

    listing.status = status;
    await listing.save();

    // Update snapshot in all threads for this listing
    await Thread.updateMany(
      { listing: listing._id },
      { 'listingSnapshot.status': status }
    );

    return successResponse(res, { status: listing.status }, 'Status updated');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── DELETE /api/listings/:id/image ───────────────────────────────────────────
// Remove a single image from a listing
const deleteImage = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    const isOwner = String(listing.owner) === String(req.user._id);
    if (!isOwner && req.user.role !== 'admin') {
      return errorResponse(res, 'Not authorized', 403);
    }

    const { imageUrl } = req.body;
    if (listing.images.length <= 1) {
      return errorResponse(res, 'Cannot remove the last image', 400);
    }

    // Delete from Cloudinary
    const publicId = imageUrl.split('/').pop().split('.')[0];
    await cloudinary.uploader.destroy(`knightmarket/listings/${publicId}`);

    listing.images = listing.images.filter((img) => img !== imageUrl);
    await listing.save();

    return successResponse(res, { images: listing.images }, 'Image removed');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── DELETE /api/listings/:id ──────────────────────────────────────────────────
const deleteListing = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    const isOwner = String(listing.owner) === String(req.user._id);
    if (!isOwner && req.user.role !== 'admin') {
      return errorResponse(res, 'Not authorized', 403);
    }

    // Remove images from Cloudinary
    for (const imageUrl of listing.images) {
      try {
        const publicId = imageUrl.split('/').pop().split('.')[0];
        await cloudinary.uploader.destroy(`knightmarket/listings/${publicId}`);
      } catch { /* ignore individual image delete failures */ }
    }

    // Remove from all users' favorites
    await User.updateMany(
      { favorites: listing._id },
      { $pull: { favorites: listing._id } }
    );

    await listing.deleteOne();

    return successResponse(res, null, 'Listing deleted');
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── POST /api/listings/:id/favorite ──────────────────────────────────────────
const toggleFavorite = async (req, res) => {
  try {
    const listing = await Listing.findById(req.params.id);
    if (!listing) return errorResponse(res, 'Listing not found', 404);

    // Owners cannot favorite their own listing
    if (String(listing.owner) === String(req.user._id)) {
      return errorResponse(res, 'You cannot favorite your own listing', 400);
    }

    const user        = await User.findById(req.user._id);
    const isFavorited = user.favorites.map(String).includes(String(listing._id));

    if (isFavorited) {
      // Unfavorite
      user.favorites = user.favorites.filter(
        (id) => String(id) !== String(listing._id)
      );
      listing.favoriteCount = Math.max(0, listing.favoriteCount - 1);
    } else {
      // Favorite
      user.favorites.push(listing._id);
      listing.favoriteCount += 1;
    }

    await user.save();
    await listing.save();

    // Emit real-time update to listing owner (Socket.io — handled in server.js)
    const io = req.app.get('io');
    if (io) {
      io.to(`user:${listing.owner}`).emit('favoriteCountUpdate', {
        listingId:     listing._id,
        favoriteCount: listing.favoriteCount,
      });
    }

    return successResponse(res, {
      isFavorited:   !isFavorited,
      favoriteCount: listing.favoriteCount,
    });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

// ── GET /api/listings/map ─────────────────────────────────────────────────────
// Lightweight endpoint for map pins — just coordinates and price
const getMapPins = async (req, res) => {
  try {
    const { category, campus } = req.query;
    const filter = { status: { $in: ['active', 'pending'] } };

    if (category) filter.category = category;
    if (campus)   filter.campus   = campus;

    const pins = await Listing.find(filter)
      .select('_id title price coordinates status images category campus isAiGenerated')
      .lean();

    return successResponse(res, { pins });
  } catch (err) {
    return errorResponse(res, err.message);
  }
};

module.exports = {
  getListings,
  getMyListings,
  getListing,
  createListing,
  updateListing,
  updateStatus,
  deleteImage,
  deleteListing,
  toggleFavorite,
  getMapPins,
};
