const express = require('express');
const router  = express.Router();
const { getPublicProfile } = require('../controllers/userController');

router.get('/:id', getPublicProfile);

module.exports = router;
