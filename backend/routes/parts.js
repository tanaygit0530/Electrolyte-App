const express = require('express');
const router = express.Router();
const partsController = require('../controllers/partsController');

router.get('/', partsController.getAllParts);
router.get('/:code', partsController.getPartByCode);

module.exports = router;
