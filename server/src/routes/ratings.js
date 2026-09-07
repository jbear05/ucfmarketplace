const express = require('express');
const router  = express.Router();
const { getUserRatings } = require('../controllers/ratingController');

router.get('/user/:id', getUserRatings);

module.exports = router;
