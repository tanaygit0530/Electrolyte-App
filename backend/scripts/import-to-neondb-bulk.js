require('dotenv').config();
const { pool } = require('../config/neondb');
const xlsx = require('xlsx');
const path = require('path');

const importBulk = async () => {
  try {
    console.log('Connecting to NeonDB...');
    
    const filePath = path.join(__dirname, '../New Part Price List.xlsx');
    console.log(`Reading Excel file from ${filePath}...`);
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    
    const data = xlsx.utils.sheet_to_json(worksheet);
    console.log(`Parsed ${data.length} rows from Excel sheet. Starting bulk NeonDB upsert...`);

    const validRows = [];
    const seenCodes = new Set();

    for (const row of data) {
      const rawCode = row['Product Code'] || row['code'];
      const rawName = row['Product Name'] || row['name'] || 'Unnamed Product';
      const rawDesc = row['Product Description'] || row['description'] || '';
      const rawPrice = row['Customer Price'] || row['customerPrice'] || 0;

      if (!rawCode) continue;

      const code = String(rawCode).trim();
      
      // De-duplicate codes in the array before bulk query to prevent ON CONFLICT row errors
      if (seenCodes.has(code)) {
        continue;
      }
      seenCodes.add(code);

      validRows.push({
        code,
        name: String(rawName).trim(),
        desc: String(rawDesc).trim(),
        price: parseFloat(rawPrice) || 0.00
      });
    }

    if (validRows.length === 0) {
      console.log('No valid products to import.');
      process.exit(0);
    }

    console.log(`Prepared ${validRows.length} unique products for bulk insert...`);

    const valuePairs = [];
    const queryParams = [];
    let paramIndex = 1;

    for (const p of validRows) {
      valuePairs.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3})`);
      queryParams.push(p.code, p.name, p.desc, p.price);
      paramIndex += 4;
    }

    const queryText = `
      INSERT INTO products (product_code, product_name, description, product_price)
      VALUES ${valuePairs.join(', ')}
      ON CONFLICT (product_code)
      DO UPDATE SET
        product_name = EXCLUDED.product_name,
        description = EXCLUDED.description,
        product_price = EXCLUDED.product_price,
        updated_at = CURRENT_TIMESTAMP;
    `;

    console.log('Sending single optimized bulk query to NeonDB...');
    const startTime = Date.now();
    const result = await pool.query(queryText, queryParams);
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`\n======================================`);
    console.log(`✔ NEONDB BULK IMPORT COMPLETE IN ${duration}s`);
    console.log(`- Successfully Upserted (Insert/Update): ${validRows.length} unique products`);
    console.log(`======================================\n`);

  } catch (error) {
    console.error('✖ Bulk Migration failed:', error);
  } finally {
    await pool.end();
    process.exit(0);
  }
};

importBulk();
