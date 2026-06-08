const express = require('express');
const cors = require('cors');
require('dotenv').config();

const chatRoutes = require('./routes/chatRoutes');
const partsRoutes = require('./routes/parts');
const ordersRoutes = require('./routes/orders');

// New Routes
const authRoutes = require('./routes/authRoutes');
const invoiceRoutes = require('./routes/invoiceRoutes');
const adminRoutes = require('./routes/adminRoutes');

const app = express();
const PORT = process.env.PORT || 5001;

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Routes
app.use('/chat', chatRoutes);
app.use('/parts', partsRoutes);
app.use('/order', ordersRoutes);
app.use('/orders', ordersRoutes);

app.use('/auth', authRoutes);
app.use('/invoice', invoiceRoutes);
app.use('/api/admin', adminRoutes);

const path = require('path');
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Global JSON Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Backend Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error'
  });
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  // Warm up Puppeteer browser instance asynchronously
  getBrowser()
    .then(() => console.log('Puppeteer browser pre-warmed and ready'))
    .catch(err => console.error('Failed to pre-warm Puppeteer browser:', err));
});

const { closeBrowser, getBrowser } = require('./services/pdfService');

// Global process error handlers to log and prevent automatic exit on unhandled promise rejections or exceptions
process.on('unhandledRejection', (reason, promise) => {
  console.error('⚠️ Unhandled Promise Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('⚠️ Uncaught Exception detected:', err);
});

// Clean shutdown listeners to close Puppeteer browser instance
process.on('SIGINT', async () => {
  console.log('Server shutting down...');
  await closeBrowser();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('Server terminated');
  await closeBrowser();
  process.exit(0);
});
