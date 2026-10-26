const express = require('express');
const router  = express.Router();

const {
  getSavedSearches,
  createSavedSearch,
  deleteSavedSearch,
} = require('../controllers/savedSearchController');

const { protect }                     = require('../middleware/auth');
const { savedSearchRules, validate } = require('../middleware/validate');

router.use(protect);

router.get(   '/',    getSavedSearches);
router.post(  '/',    savedSearchRules, validate, createSavedSearch);
router.delete('/:id', deleteSavedSearch);

module.exports = router;
