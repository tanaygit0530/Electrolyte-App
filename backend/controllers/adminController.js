const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/neondb');
const XLSX = require('xlsx');
const ExcelJS = require('exceljs');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
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
      const { productCode, stockQuantity, location } = row;

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

      validRows.push({ 
        productCode: code, 
        qty, 
        location: location ? String(location).trim() : 'N/A' 
      });
    }

    // 2. Execute single highly-optimized bulk upsert query
    if (validRows.length > 0) {
      const valuePairs = [];
      const queryParams = [];
      let paramIndex = 1;

      for (const r of validRows) {
        valuePairs.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, 0.00, $${paramIndex + 3})`);
        queryParams.push(r.productCode, r.productCode, r.qty, r.location);
        paramIndex += 4;
      }

      // If product doesn't exist, insert it with price 0.00 and location. 
      // If it exists, update stock_quantity and location (preserving the existing price).
      const bulkUpsertQuery = `
        INSERT INTO products (product_code, product_name, stock_quantity, product_price, location)
        VALUES ${valuePairs.join(', ')}
        ON CONFLICT (product_code)
        DO UPDATE SET 
          stock_quantity = EXCLUDED.stock_quantity,
          location = EXCLUDED.location,
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

// Get all users
const getUsers = async (req, res) => {
  try {
    const result = await pool.query('SELECT id, email, role, created_at FROM users ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Get Users Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

// Create a new user (technician or admin)
const createUser = async (req, res) => {
  const { email, password, role } = req.body;

  if (!email || !password || !role) {
    return res.status(400).json({ error: 'Email, password, and role are required' });
  }

  if (role !== 'admin' && role !== 'technician') {
    return res.status(400).json({ error: 'Invalid role. Must be admin or technician' });
  }

  let client;
  try {
    const lowerEmail = email.toLowerCase().trim();
    
    // Check if user already exists
    const checkUser = await pool.query('SELECT * FROM users WHERE email = $1', [lowerEmail]);
    if (checkUser.rows.length > 0) {
      return res.status(400).json({ error: 'A user with this email already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    client = await pool.connect();
    await client.query('BEGIN');

    // Insert into users table
    const userInsert = await client.query(
      'INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3) RETURNING id, email, role, created_at',
      [lowerEmail, passwordHash, role]
    );
    const newUser = userInsert.rows[0];

    // If role is admin, also insert into admins table
    if (role === 'admin') {
      await client.query(
        'INSERT INTO admins (email, password_hash) VALUES ($1, $2)',
        [lowerEmail, passwordHash]
      );
    }

    await client.query('COMMIT');

    res.status(201).json({
      message: 'User created successfully',
      user: newUser
    });

  } catch (error) {
    if (client) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        console.error('Error rolling back user creation:', rollbackError);
      }
    }
    console.error('Create User Error:', error);
    res.status(500).json({ error: 'Internal Server Error creating user' });
  } finally {
    if (client) {
      client.release();
    }
  }
};

// Helper query builder for reports
const getFilteredInvoicesQuery = (queryParams) => {
  const { technicians, mops, dateRange, startDate, endDate, customerSearch, invoiceSearch } = queryParams;
  
  let query = `SELECT * FROM invoices`;
  const conditions = [];
  const params = [];
  let paramIdx = 1;
  
  // 1. Technician Filter (Multi Select)
  if (technicians && technicians !== 'null') {
    const techList = Array.isArray(technicians) ? technicians : technicians.split(',').map(s => s.trim()).filter(Boolean);
    if (techList.length > 0) {
      conditions.push(`technician_name = ANY($${paramIdx})`);
      params.push(techList);
      paramIdx++;
    }
  }
  
  // 2. MOP Filter (Multi Select)
  if (mops && mops !== 'null') {
    const mopList = Array.isArray(mops) ? mops : mops.split(',').map(s => s.trim()).filter(Boolean);
    if (mopList.length > 0) {
      conditions.push(`mop = ANY($${paramIdx})`);
      params.push(mopList);
      paramIdx++;
    }
  }
  
  // 3. Date Range Filter
  let start, end;
  const now = new Date();
  if (dateRange === 'today') {
    start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
    end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  } else if (dateRange === 'thisWeek') {
    const day = now.getDay();
    const diff = now.getDate() - day + (day === 0 ? -6 : 1); // Monday
    start = new Date(now.setDate(diff));
    start.setHours(0, 0, 0, 0);
    end = new Date();
    end.setHours(23, 59, 59, 999);
  } else if (dateRange === 'thisMonth') {
    start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  } else if (dateRange === 'custom' && startDate && endDate) {
    start = new Date(startDate);
    start.setHours(0, 0, 0, 0);
    end = new Date(endDate);
    end.setHours(23, 59, 59, 999);
  }
  
  if (start && end) {
    conditions.push(`created_at >= $${paramIdx} AND created_at <= $${paramIdx+1}`);
    params.push(start, end);
    paramIdx += 2;
  }
  
  // 4. Customer Search
  if (customerSearch) {
    conditions.push(`customer_name ILIKE $${paramIdx}`);
    params.push(`%${customerSearch}%`);
    paramIdx++;
  }
  
  // 5. Invoice Search
  if (invoiceSearch) {
    conditions.push(`invoice_number ILIKE $${paramIdx}`);
    params.push(`%${invoiceSearch}%`);
    paramIdx++;
  }
  
  if (conditions.length > 0) {
    query += ` WHERE ` + conditions.join(' AND ');
  }
  
  query += ` ORDER BY created_at DESC`;
  
  return { query, params };
};

// GET /api/admin/reports/technician-revenue
const getTechnicianRevenueReport = async (req, res) => {
  try {
    const { query, params } = getFilteredInvoicesQuery(req.query);
    const result = await pool.query(query, params);
    
    // Get unique technicians list from all invoices in database for filter options
    const allTechsRes = await pool.query(`
      SELECT DISTINCT technician_name 
      FROM invoices 
      WHERE technician_name IS NOT NULL AND technician_name != ''
      ORDER BY technician_name
    `);
    const techniciansList = allTechsRes.rows.map(r => r.technician_name);
    
    // Calculate metrics
    let totalRevenue = 0;
    let cashRevenue = 0;
    let upiRevenue = 0;
    let otherRevenue = 0;
    const techSummaryMap = {};
    
    const formattedInvoices = result.rows.map(inv => {
      const amount = parseFloat(inv.total_amount) || 0;
      totalRevenue += amount;
      
      const mop = (inv.mop || 'UPI').toUpperCase();
      if (mop === 'CASH') {
        cashRevenue += amount;
      } else if (mop === 'UPI') {
        upiRevenue += amount;
      } else {
        otherRevenue += amount;
      }
      
      const tech = inv.technician_name || 'Unknown';
      techSummaryMap[tech] = (techSummaryMap[tech] || 0) + amount;
      
      // format items description and averages
      let items = [];
      try {
        items = typeof inv.items === 'string' ? JSON.parse(inv.items) : (inv.items || []);
      } catch(e) {}
      
      const partDesc = items.map(i => i.description || i.name).join(', ');
      const itemPrice = items.length > 0 ? (items.reduce((sum, i) => sum + (parseFloat(i.rate) || 0), 0) / items.length) : 0;
      
      return {
        id: String(inv.id),
        invoiceNumber: inv.invoice_number,
        technicianName: inv.technician_name,
        customerName: inv.customer_name,
        customerEmail: inv.customer_email,
        customerPhone: inv.customer_phone,
        subTotal: parseFloat(inv.sub_total) || 0,
        gstAmount: parseFloat(inv.gst_amount) || 0,
        serviceCharge: parseFloat(inv.service_charge) || 0,
        totalAmount: amount,
        pdfUrl: inv.pdf_url,
        status: inv.status,
        brand: inv.brand,
        serialNumber: inv.serial_number,
        caseId: inv.case_id,
        warrantyType: inv.warranty_type,
        preparedBy: inv.prepared_by,
        mop: inv.mop || 'UPI',
        zipCode: inv.zip_code || '400001',
        remark: inv.remark || '',
        createdAt: inv.created_at,
        updatedAt: inv.updated_at,
        productDescription: inv.brand || 'Atomberg',
        partDescription: partDesc,
        productItemPrice: itemPrice
      };
    });
    
    const totalInvoices = formattedInvoices.length;
    const totalTechniciansCount = Object.keys(techSummaryMap).length;
    
    res.json({
      invoices: formattedInvoices,
      techniciansList,
      summary: {
        totalRevenue,
        totalInvoices,
        totalTechnicians: totalTechniciansCount,
        cashRevenue,
        upiRevenue,
        otherRevenue
      }
    });
  } catch (error) {
    console.error('Get Technician Revenue Report Error:', error);
    res.status(500).json({ error: 'Internal Server Error fetching report' });
  }
};

// GET /api/admin/reports/technician-summary
const getTechnicianSummaryReport = async (req, res) => {
  try {
    const { query, params } = getFilteredInvoicesQuery(req.query);
    const result = await pool.query(query, params);
    
    const techSummaryMap = {};
    let grandTotal = 0;
    
    result.rows.forEach(inv => {
      const amount = parseFloat(inv.total_amount) || 0;
      grandTotal += amount;
      const tech = inv.technician_name || 'Unknown';
      techSummaryMap[tech] = (techSummaryMap[tech] || 0) + amount;
    });
    
    const summary = Object.entries(techSummaryMap).map(([name, amount]) => ({
      technicianName: name,
      totalAmount: amount
    }));
    
    // Sort technicians by total amount descending
    summary.sort((a, b) => b.totalAmount - a.totalAmount);
    
    res.json({
      summary,
      grandTotal
    });
  } catch (error) {
    console.error('Get Technician Summary Report Error:', error);
    res.status(500).json({ error: 'Internal Server Error fetching summary' });
  }
};

// GET /api/admin/reports/export-excel
const exportExcelReport = async (req, res) => {
  try {
    // 1. Get all invoices matching filters including MOP (for a filtered export)
    const { query, params } = getFilteredInvoicesQuery(req.query);
    const result = await pool.query(query, params);
    const invoices = result.rows;
    
    // Find selected MOP from query
    let selectedMop = 'All';
    if (req.query.mops) {
      const mopList = req.query.mops.split(',').map(s => s.trim()).filter(Boolean);
      if (mopList.length > 0) {
        selectedMop = mopList.join(', ');
      }
    }
    
    // Set up temp output folder and file path in local scratch directory
    const tempDir = path.join(__dirname, '..', 'scratch');
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
    const tempOutFile = path.join(tempDir, `temp_report_${Date.now()}.xlsx`);
    
    // Spawn Python script to populate excel template and refresh pivot table
    const scriptPath = path.join(__dirname, '..', 'services', 'excel_generator.py');
    const pythonCmd = fs.existsSync('/opt/anaconda3/bin/python3') ? '/opt/anaconda3/bin/python3' : 'python3';
    const pythonProc = spawn(pythonCmd, [scriptPath, tempOutFile, selectedMop]);
    
    // Write invoices array as JSON to stdin
    pythonProc.stdin.write(JSON.stringify(invoices));
    pythonProc.stdin.end();
    
    let stderr = '';
    pythonProc.stderr.on('data', (data) => {
      stderr += data;
    });
    
    pythonProc.on('close', async (code) => {
      if (code !== 0) {
        console.error('Python Pivot Generator Error (stderr):', stderr);
        return res.status(500).json({ error: 'Excel generation failed', details: stderr });
      }
      
      try {
        // Read file contents, send as response, and clean up
        const buf = fs.readFileSync(tempOutFile);
        
        // Export file name formatting: OW_Report_DD-MM-YYYY.xlsx
        const today = new Date();
        const dd = String(today.getDate()).padStart(2, '0');
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const yyyy = today.getFullYear();
        const formattedDate = `${dd}-${mm}-${yyyy}`;
        const filename = `OW_Report_${formattedDate}.xlsx`;
        
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.send(buf);
        
        // Delete temp file asynchronously
        fs.unlink(tempOutFile, (err) => {
          if (err) console.error('Error deleting temp Excel file:', err);
        });
      } catch (err) {
        console.error('Error reading generated Excel:', err);
        res.status(500).json({ error: 'Internal Server Error reading export' });
      }
    });
  } catch (error) {
    console.error('Export Excel Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

module.exports = {
  login,
  uploadStock,
  uploadPrice,
  getDashboardStats,
  getStockHistory,
  getPriceHistory,
  getUsers,
  createUser,
  getTechnicianRevenueReport,
  getTechnicianSummaryReport,
  exportExcelReport
};
