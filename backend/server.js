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
});

const { closeBrowser } = require('./services/pdfService');

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