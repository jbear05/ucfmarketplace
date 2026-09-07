const express = require('express');
const router  = express.Router();

const {
  createThread,
  contactAdmin,
  getThreads,
  getMessages,
  sendMessage,
  blockThread,
  deleteThread,
  getUnreadCount,
  proposeMeetup,
  respondMeetup,
  completeMeetup,
  rateThread,
} = require('../controllers/chatController');

const { protect }      = require('../middleware/auth');
const { messageRules, meetupRules, rateRules, validate } = require('../middleware/validate');

router.use(protect); // all chat routes require auth

router.get( '/',                   getThreads);
router.get( '/unread-count',       getUnreadCount);
router.post('/',                   createThread);
router.post('/contact-admin',      contactAdmin);
router.get( '/:id/messages',       getMessages);
router.post('/:id/messages',       messageRules, validate, sendMessage);
router.patch('/:id/block',         blockThread);
router.patch('/:id/delete',        deleteThread);
router.patch('/:id/meetup',          meetupRules, validate, proposeMeetup);
router.patch('/:id/meetup/respond',  respondMeetup);
router.patch('/:id/meetup/complete', completeMeetup);
router.post( '/:id/rate',            rateRules, validate, rateThread);

module.exports = router;
