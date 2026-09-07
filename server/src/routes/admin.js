const express = require('express');
const router  = express.Router();
const { protect, adminOnly } = require('../middleware/auth');
const {
  getUsers, updateUser, deleteUser,
  getAllListings, reactivateListing, adminDeleteListing, toggleBoost,
  getAllThreads,
  getStats,
} = require('../controllers/adminController');

router.use(protect, adminOnly); // all admin routes require auth + admin role

// Dashboard
router.get('/stats',                    getStats);

// Users
router.get(   '/users',                 getUsers);
router.patch( '/users/:id',             updateUser);
router.delete('/users/:id',             deleteUser);

// Listings
router.get(   '/listings',              getAllListings);
router.patch( '/listings/:id/reactivate', reactivateListing);
router.patch( '/listings/:id/boost',    toggleBoost);
router.delete('/listings/:id',          adminDeleteListing);

// Threads (moderation)
router.get('/threads',                  getAllThreads);

module.exports = router;
