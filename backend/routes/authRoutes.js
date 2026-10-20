const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { requireTechnicianAuth } = require('../middleware/auth');

router.post('/login', authController.login);
router.post('/forgot-password', authController.forgotPassword);
router.post('/reset-password', authController.resetPassword);
router.patch('/change-password', requireTechnicianAuth, authController.changePassword);

module.exports = router;
