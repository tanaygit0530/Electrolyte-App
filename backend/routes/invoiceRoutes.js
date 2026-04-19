const express = require('express');
const router = express.Router();
const invoiceController = require('../controllers/invoiceController');
const { requireTechnicianAuth } = require('../middleware/auth');

router.use(requireTechnicianAuth);

router.post('/', invoiceController.createInvoice);
router.get('/', invoiceController.getInvoices);

module.exports = router;
