const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const adminAuth = require('../middleware/adminAuth');

// Auth routes (Public)
router.post('/login', adminController.login);

// Protected routes (Requires Admin JWT)
router.post('/upload-stock', adminAuth, adminController.uploadStock);
router.post('/upload-price', adminAuth, adminController.uploadPrice);
router.get('/dashboard', adminAuth, adminController.getDashboardStats);
router.get('/stock-history', adminAuth, adminController.getStockHistory);
router.get('/price-history', adminAuth, adminController.getPriceHistory);

module.exports = router;
