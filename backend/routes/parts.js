const express = require('express');
const router = express.Router();
const partsController = require('../controllers/partsController');
const { requireTechnicianAuth } = require('../middleware/auth');

router.use(requireTechnicianAuth);

router.get('/', partsController.getAllParts);
router.get('/search', partsController.searchParts);
router.get('/:code', partsController.getPartByCode);

module.exports = router;
