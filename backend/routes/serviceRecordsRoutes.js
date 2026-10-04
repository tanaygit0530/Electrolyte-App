const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const serviceRecordsController = require('../controllers/serviceRecordsController');

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Multer disk storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + '-' + file.originalname);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit to comfortably handle Data.xlsx
});

// Single serial number verification (Used by Customer App & Technicians)
router.get('/check/:serialNumber', serviceRecordsController.checkSerialNumber);

// Bulk file upload & 60-day audit (Used by Admin App)
router.post('/upload', upload.single('file'), serviceRecordsController.uploadServiceFile);

// Upload history audit logs
router.get('/history', serviceRecordsController.getUploadHistory);

// List all found records currently within the 60-day window
router.get('/found-entries', serviceRecordsController.getFoundEntries);

// Export CSV of found records
router.get('/export-found', serviceRecordsController.exportFoundCsv);

module.exports = router;
