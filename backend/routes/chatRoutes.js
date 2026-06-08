const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { requireTechnicianAuth } = require('../middleware/auth');

router.use(requireTechnicianAuth);

router.post('/', chatController.processChat);
router.get('/sessions', chatController.getSessions);
router.get('/sessions/:sessionId/messages', chatController.getSessionMessages);


module.exports = router;
