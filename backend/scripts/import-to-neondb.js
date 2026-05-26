require('dotenv').config();
const { pool } = require('../config/neondb');
const xlsx = require('xlsx');
const path = require('path');

const importToNeonDB = async () => {
  try {
    console.log('Connecting to NeonDB...');
    const timeRes = await pool.query('SELECT NOW()');
    console.log('✔ NeonDB Connected! Server Time:', timeRes.rows[0].now);

    const filePath = path.join(__dirname, '../New Part Price List.xlsx');
    console.log(`Reading Excel file from ${filePath}...`);
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    
    // Parse to JSON
    const data = xlsx.utils.sheet_to_json(worksheet);
    console.log(`Parsed ${data.length} rows from Excel sheet. Starting NeonDB import...`);

    let insertedCount = 0;
    let skippedCount = 0;
    let failedCount = 0;

    // Use a transaction or single connection client
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      for (const row of data) {
        const rawCode = row['Product Code'] || row['code'];
        const rawName = row['Product Name'] || row['name'] || 'Unnamed Product';
        const rawDesc = row['Product Description'] || row['description'] || '';
        const rawPrice = row['Customer Price'] || row['customerPrice'] || 0;

        if (!rawCode) {
          skippedCount++;
          continue;
        }

        const code = String(rawCode).trim();
        const name = String(rawName).trim();
        const desc = String(rawDesc).trim();
        const price = parseFloat(rawPrice) || 0.00;

        try {
          // Insert product if it doesn't exist, or update name/description/price if it does
          await client.query(
            `INSERT INTO products (product_code, product_name, description, product_price) 
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (product_code) 
             DO UPDATE SET 
               product_name = EXCLUDED.product_name,
               description = EXCLUDED.description,
               product_price = EXCLUDED.product_price,
               updated_at = CURRENT_TIMESTAMP`,
            [code, name, desc, price]
          );
          insertedCount++;
        } catch (dbErr) {
          console.error(`Failed to import code ${code}:`, dbErr.message);
          failedCount++;
        }
      }

      await client.query('COMMIT');
      console.log('\n======================================');
      console.log('✔ NEONDB IMPORT COMPLETE');
      console.log(`- Total Records Processed: ${data.length}`);
      console.log(`- Successfully Upserted (Insert/Update): ${insertedCount}`);
      console.log(`- Skipped (Missing code): ${skippedCount}`);
      console.log(`- Database Write Failures: ${failedCount}`);
      console.log('======================================\n');

    } catch (txErr) {
      await client.query('ROLLBACK');
      throw txErr;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('✖ Migration failed:', error);
  } finally {
    await pool.end();
    process.exit(0);
  }
};

importToNeonDB();
