const express = require('express');
const router = express.Router();
const ordersController = require('../controllers/ordersController');
const { requireTechnicianAuth } = require('../middleware/auth');

router.use(requireTechnicianAuth);

router.post('/', ordersController.createOrder);
router.get('/', ordersController.getAllOrders);

module.exports = router;
