const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { Client } = require('pg');
const WebSocket = require('ws');
const url = require('url');
const jwt = require('jsonwebtoken');
const { pool } = require('./config/neondb');

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

const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
  // Warm up Puppeteer browser instance asynchronously
  getBrowser()
    .then(() => console.log('Puppeteer browser pre-warmed and ready'))
    .catch(err => console.error('Failed to pre-warm Puppeteer browser:', err));

  // Initialize DB Trigger and Real-time listener
  setupDatabaseTriggerAndListener();
});

// Setup Real-time WebSocket Broadcaster
const wssClients = new Set();

const broadcastDashboardStats = async () => {
  try {
    const prodCountRes = await pool.query('SELECT COUNT(*) FROM products');
    const totalProducts = parseInt(prodCountRes.rows[0].count || 0);

    const stockSumRes = await pool.query('SELECT SUM(stock_quantity) FROM products');
    const totalStock = parseInt(stockSumRes.rows[0].sum || 0);

    const lastStockUploadRes = await pool.query('SELECT uploaded_at FROM stock_upload_history ORDER BY uploaded_at DESC LIMIT 1');
    const lastStockUpload = lastStockUploadRes.rows[0] ? lastStockUploadRes.rows[0].uploaded_at : null;

    const lastPriceUploadRes = await pool.query('SELECT uploaded_at FROM price_upload_history ORDER BY uploaded_at DESC LIMIT 1');
    const lastPriceUpload = lastPriceUploadRes.rows[0] ? lastPriceUploadRes.rows[0].uploaded_at : null;

    const payload = JSON.stringify({
      totalProducts,
      totalStock,
      lastStockUpload,
      lastPriceUpload
    });

    for (const client of wssClients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(payload);
      }
    }
  } catch (err) {
    console.error('Failed to broadcast dashboard stats:', err);
  }
};

const broadcastInvoiceUpdate = async () => {
  try {
    const payload = JSON.stringify({
      type: 'invoice_update'
    });

    for (const client of wssClients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(payload);
      }
    }
  } catch (err) {
    console.error('Failed to broadcast invoice update:', err);
  }
};

const setupDatabaseTriggerAndListener = async () => {
  try {
    // 1. Create statement-level trigger in DB to notify on products and invoices updates
    const triggerQueries = [
      `CREATE OR REPLACE FUNCTION notify_products_change()
       RETURNS trigger AS $$
       BEGIN
         PERFORM pg_notify('products_channel', 'change');
         RETURN NULL;
       END;
       $$ LANGUAGE plpgsql;`,
      `DROP TRIGGER IF EXISTS products_change_trigger ON products;`,
      `CREATE TRIGGER products_change_trigger
       AFTER INSERT OR UPDATE OR DELETE ON products
       FOR EACH STATEMENT
       EXECUTE FUNCTION notify_products_change();`,
       
      `CREATE OR REPLACE FUNCTION notify_invoices_change()
       RETURNS trigger AS $$
       BEGIN
         PERFORM pg_notify('invoices_channel', 'change');
         RETURN NULL;
       END;
       $$ LANGUAGE plpgsql;`,
      `DROP TRIGGER IF EXISTS invoices_change_trigger ON invoices;`,
      `CREATE TRIGGER invoices_change_trigger
       AFTER INSERT OR UPDATE OR DELETE ON invoices
       FOR EACH STATEMENT
       EXECUTE FUNCTION notify_invoices_change();`
    ];

    for (const q of triggerQueries) {
      await pool.query(q);
    }
    console.log('PostgreSQL trigger functions set up successfully');

    // 2. Set up a dedicated client to LISTEN to the channel
    const listenClient = new Client({
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false }
    });

    await listenClient.connect();
    await listenClient.query('LISTEN products_channel');
    await listenClient.query('LISTEN invoices_channel');
    console.log('Listening to PostgreSQL notifications (products_channel, invoices_channel)...');

    listenClient.on('notification', (msg) => {
      console.log(`Received PostgreSQL notification on ${msg.channel}. Broadcasting...`);
      if (msg.channel === 'products_channel') {
        broadcastDashboardStats();
      } else if (msg.channel === 'invoices_channel') {
        broadcastInvoiceUpdate();
      }
    });

    listenClient.on('error', (err) => {
      console.error('Dedicated LISTEN client connection error:', err);
      // Attempt reconnect after 5 seconds
      setTimeout(setupDatabaseTriggerAndListener, 5000);
    });

  } catch (err) {
    console.error('Failed to set up PostgreSQL database trigger or listener:', err);
    setTimeout(setupDatabaseTriggerAndListener, 5000);
  }
};

const wss = new WebSocket.Server({ server });

wss.on('connection', async (ws, req) => {
  try {
    const parameters = url.parse(req.url, true).query;
    const token = parameters.token;

    if (!token) {
      console.warn('WS Connection attempt rejected: Missing token');
      ws.close(4001, 'Token Required');
      return;
    }

    const secret = process.env.JWT_SECRET || 'prasadinternatelectrolyte';
    let decoded;
    try {
      decoded = jwt.verify(token, secret);
    } catch (err) {
      console.error('WS Connection unauthorized:', err.message);
      ws.close(4001, 'Invalid Token');
      return;
    }

    console.log(`WS Connection authorized for admin: ${decoded.email}`);
    wssClients.add(ws);

    // Send initial stats on connect
    try {
      const prodCountRes = await pool.query('SELECT COUNT(*) FROM products');
      const totalProducts = parseInt(prodCountRes.rows[0].count || 0);

      const stockSumRes = await pool.query('SELECT SUM(stock_quantity) FROM products');
      const totalStock = parseInt(stockSumRes.rows[0].sum || 0);

      const lastStockUploadRes = await pool.query('SELECT uploaded_at FROM stock_upload_history ORDER BY uploaded_at DESC LIMIT 1');
      const lastStockUpload = lastStockUploadRes.rows[0] ? lastStockUploadRes.rows[0].uploaded_at : null;

      const lastPriceUploadRes = await pool.query('SELECT uploaded_at FROM price_upload_history ORDER BY uploaded_at DESC LIMIT 1');
      const lastPriceUpload = lastPriceUploadRes.rows[0] ? lastPriceUploadRes.rows[0].uploaded_at : null;

      ws.send(JSON.stringify({
        totalProducts,
        totalStock,
        lastStockUpload,
        lastPriceUpload
      }));
    } catch (err) {
      console.error('Error sending initial stats to WS client:', err);
    }

    ws.on('close', () => {
      wssClients.delete(ws);
      console.log('Admin client disconnected from WS');
    });

  } catch (err) {
    console.error('WS Connection error:', err);
    ws.close(1011, 'Internal Server Error');
  }
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
