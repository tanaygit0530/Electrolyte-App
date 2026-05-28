const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/neondb');
require('dotenv').config();

// JWT Admin Login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Please enter an email and password' });
    }

    const adminQuery = await pool.query('SELECT * FROM admins WHERE email = $1', [email.toLowerCase().trim()]);
    const admin = adminQuery.rows[0];

    if (!admin) {
      return res.status(401).json({ error: 'No admin found with this email' });
    }

    const isPasswordValid = await bcrypt.compare(password, admin.password_hash);

    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid password' });
    }

    const secret = process.env.JWT_SECRET || 'prasadinternatelectrolyte';
    const token = jwt.sign(
      { id: admin.id, email: admin.email, role: 'admin' },
      secret,
      { expiresIn: '1d' }
    );

    res.json({
      message: 'Admin logged in successfully',
      token,
      admin: {
        id: admin.id,
        email: admin.email,
        role: 'admin'
      }
    });

  } catch (error) {
    console.error('Admin Login Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

// Daily Stock Sheet Upload
const uploadStock = async (req, res) => {
  const { fileName, rows } = req.body;
  const uploadedBy = req.admin ? req.admin.email : 'Admin';

  if (!fileName || !Array.isArray(rows)) {
    return res.status(400).json({ error: 'Invalid payload. File name and rows array are required.' });
  }

  let client;
  try {
    client = await pool.connect();
    await client.query('BEGIN');

    let totalRows = rows.length;
    let updatedRows = 0;
    let failedRows = 0;
    const errors = [];
    const validRows = [];
    const seenCodes = new Set();

    // 1. Validate rows in memory
    for (const row of rows) {
      const { productCode, stockQuantity } = row;

      if (!productCode) {
        failedRows++;
        errors.push({ productCode: 'N/A', error: 'Missing product code' });
        continue;
      }

      const code = String(productCode).trim();

      if (stockQuantity === undefined || stockQuantity === null || isNaN(stockQuantity)) {
        failedRows++;
        errors.push({ productCode: code, error: 'Missing or invalid quantity' });
        continue;
      }

      const qty = parseInt(stockQuantity);
      if (qty < 0) {
        failedRows++;
        errors.push({ productCode: code, error: `Negative stock quantity: ${qty}` });
        continue;
      }

      if (seenCodes.has(code)) {
        failedRows++;
        errors.push({ productCode: code, error: 'Duplicate product code in spreadsheet' });
        continue;
      }
      seenCodes.add(code);

      validRows.push({ productCode: code, qty });
    }

    // 2. Execute single highly-optimized bulk upsert query
    if (validRows.length > 0) {
      const valuePairs = [];
      const queryParams = [];
      let paramIndex = 1;

      for (const r of validRows) {
        valuePairs.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, 0.00)`);
        queryParams.push(r.productCode, r.productCode, r.qty);
        paramIndex += 3;
      }

      // If product doesn't exist, insert it with price 0.00. 
      // If it exists, only update stock_quantity (preserving the existing price).
      const bulkUpsertQuery = `
        INSERT INTO products (product_code, product_name, stock_quantity, product_price)
        VALUES ${valuePairs.join(', ')}
        ON CONFLICT (product_code)
        DO UPDATE SET 
          stock_quantity = EXCLUDED.stock_quantity,
          updated_at = CURRENT_TIMESTAMP;
      `;

      await client.query(bulkUpsertQuery, queryParams);
      updatedRows = validRows.length;
    }

    // 3. Save to history
    await client.query(
      'INSERT INTO stock_upload_history (file_name, uploaded_by, total_rows, updated_rows, failed_rows) VALUES ($1, $2, $3, $4, $5)',
      [fileName, uploadedBy, totalRows, updatedRows, failedRows]
    );

    await client.query('COMMIT');

    res.json({
      success: true,
      message: `Stock upload processed. ${updatedRows} added/updated, ${failedRows} failed.`,
      summary: {
        totalRows,
        updatedRows,
        failedRows,
        errors
      }
    });

  } catch (error) {
    if (client) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Error rolling back transaction:', rollbackError);
      }
    }
    console.error('Stock Upload Controller Error:', error);
    res.status(500).json({ error: 'Internal Server Error processing stock upload' });
  } finally {
    if (client) {
      client.release();
    }
  }
};

// Price Sheet Upload
const uploadPrice = async (req, res) => {
  const { fileName, rows } = req.body;
  const uploadedBy = req.admin ? req.admin.email : 'Admin';

  if (!fileName || !Array.isArray(rows)) {
    return res.status(400).json({ error: 'Invalid payload. File name and rows array are required.' });
  }

  let client;
  try {
    client = await pool.connect();
    await client.query('BEGIN');

    let totalRows = rows.length;
    let updatedRows = 0;
    let failedRows = 0;
    const errors = [];
    const validRows = [];
    const seenCodes = new Set();

    // 1. Validate rows in memory
    for (const row of rows) {
      const { productCode, productPrice } = row;

      if (!productCode) {
        failedRows++;
        errors.push({ productCode: 'N/A', error: 'Missing product code' });
        continue;
      }

      const code = String(productCode).trim();

      if (productPrice === undefined || productPrice === null || isNaN(productPrice)) {
        failedRows++;
        errors.push({ productCode: code, error: 'Missing or invalid price' });
        continue;
      }

      const price = parseFloat(productPrice);
      if (price < 0) {
        failedRows++;
        errors.push({ productCode: code, error: `Negative price: ${price}` });
        continue;
      }

      if (seenCodes.has(code)) {
        failedRows++;
        errors.push({ productCode: code, error: 'Duplicate product code in spreadsheet' });
        continue;
      }
      seenCodes.add(code);

      validRows.push({ productCode: code, price });
    }

    // 2. Execute single highly-optimized bulk upsert query
    if (validRows.length > 0) {
      const valuePairs = [];
      const queryParams = [];
      let paramIndex = 1;

      for (const r of validRows) {
        valuePairs.push(`($${paramIndex}, $${paramIndex + 1}, 0, $${paramIndex + 2}::numeric)`);
        queryParams.push(r.productCode, r.productCode, r.price);
        paramIndex += 3;
      }

      // If product doesn't exist, insert it with stock 0.
      // If it exists, only update product_price (preserving the existing stock).
      const bulkUpsertQuery = `
        INSERT INTO products (product_code, product_name, stock_quantity, product_price)
        VALUES ${valuePairs.join(', ')}
        ON CONFLICT (product_code)
        DO UPDATE SET 
          product_price = EXCLUDED.product_price,
          updated_at = CURRENT_TIMESTAMP;
      `;

      await client.query(bulkUpsertQuery, queryParams);
      updatedRows = validRows.length;
    }

    // 3. Save to history
    await client.query(
      'INSERT INTO price_upload_history (file_name, uploaded_by, total_rows, updated_rows, failed_rows) VALUES ($1, $2, $3, $4, $5)',
      [fileName, uploadedBy, totalRows, updatedRows, failedRows]
    );

    await client.query('COMMIT');

    res.json({
      success: true,
      message: `Price upload processed. ${updatedRows} added/updated, ${failedRows} failed.`,
      summary: {
        totalRows,
        updatedRows,
        failedRows,
        errors
      }
    });

  } catch (error) {
    if (client) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Error rolling back transaction:', rollbackError);
      }
    }
    console.error('Price Upload Controller Error:', error);
    res.status(500).json({ error: 'Internal Server Error processing price upload' });
  } finally {
    if (client) {
      client.release();
    }
  }
};

// Dashboard aggregations
const getDashboardStats = async (req, res) => {
  try {
    // Total distinct products
    const prodCountRes = await pool.query('SELECT COUNT(*) FROM products');
    const totalProducts = parseInt(prodCountRes.rows[0].count || 0);

    // Sum of all stock quantities
    const stockSumRes = await pool.query('SELECT SUM(stock_quantity) FROM products');
    const totalStock = parseInt(stockSumRes.rows[0].sum || 0);

    // Last Stock Upload Date
    const lastStockUploadRes = await pool.query('SELECT uploaded_at FROM stock_upload_history ORDER BY uploaded_at DESC LIMIT 1');
    const lastStockUpload = lastStockUploadRes.rows[0] ? lastStockUploadRes.rows[0].uploaded_at : null;

    // Last Price Upload Date
    const lastPriceUploadRes = await pool.query('SELECT uploaded_at FROM price_upload_history ORDER BY uploaded_at DESC LIMIT 1');
    const lastPriceUpload = lastPriceUploadRes.rows[0] ? lastPriceUploadRes.rows[0].uploaded_at : null;

    res.json({
      totalProducts,
      totalStock,
      lastStockUpload,
      lastPriceUpload
    });
  } catch (error) {
    console.error('Dashboard Stats Error:', error);
    res.status(500).json({ error: 'Internal Server Error fetching dashboard stats' });
  }
};

// Stock history log
const getStockHistory = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM stock_upload_history ORDER BY uploaded_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Stock History Error:', error);
    res.status(500).json({ error: 'Internal Server Error fetching stock upload history' });
  }
};

// Price history log
const getPriceHistory = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM price_upload_history ORDER BY uploaded_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Price History Error:', error);
    res.status(500).json({ error: 'Internal Server Error fetching price upload history' });
  }
};

module.exports = {
  login,
  uploadStock,
  uploadPrice,
  getDashboardStats,
  getStockHistory,
  getPriceHistory
};
