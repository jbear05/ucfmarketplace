const express = require('express');
const router  = express.Router();

const {
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
} = require('../controllers/listingController');

const { protect, optionalAuth }                  = require('../middleware/auth');
const { listingRules, listingStatusRules, validate } = require('../middleware/validate');
const { uploadListingImages }                    = require('../config/cloudinary');

// Public (with optional auth to get favorite state)
router.get('/',      optionalAuth, getListings);
router.get('/map',   optionalAuth, getMapPins);
router.get('/mine',  protect,      getMyListings);
router.get('/:id',   optionalAuth, getListing);

// Protected — must be logged in
router.post(
  '/',
  protect,
  uploadListingImages.array('images', 10), // max 10 images
  listingRules,
  validate,
  createListing
);

router.put(
  '/:id',
  protect,
  uploadListingImages.array('images', 10),
  listingRules,
  validate,
  updateListing
);

router.patch('/:id/status',    protect, listingStatusRules, validate, updateStatus);
router.delete('/:id/image',    protect, deleteImage);
router.delete('/:id',          protect, deleteListing);
router.post('/:id/favorite',   protect, toggleFavorite);

module.exports = router;
