require('dotenv').config();
const { pool } = require('../config/neondb');
const xlsx = require('xlsx');
const path = require('path');

const importStockCSV = async () => {
  try {
    console.log('Connecting to NeonDB...');
    
    const filePath = path.join(__dirname, '../resources/stockupdatetemplate.csv');
    console.log(`Reading CSV file from ${filePath}...`);
    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    
    const data = xlsx.utils.sheet_to_json(worksheet);
    console.log(`Parsed ${data.length} rows from CSV. Starting NeonDB bulk upsert...`);

    const aggregatedMap = new Map();

    for (const row of data) {
      const rawCode = row['Product Code'] || row['code'] || row['Product_Code'];
      const rawName = row['Product Description'] || row['name'] || row['Product_Name'] || 'Unnamed Product';
      const rawDesc = row['Product Description'] || row['description'] || '';
      const rawQty = row['Quantity On Hand'] || row['stockQuantity'] || row['quantity'] || 0;
      const rawPrice = row['Product Price'] || row['price'] || 0.00;
      const rawLocation = row['Location Name'] || row['location'] || 'N/A';

      if (!rawCode) continue;

      const code = String(rawCode).trim();
      const qty = parseInt(rawQty) || 0;
      const price = parseFloat(rawPrice) || 0.00;
      const locStr = String(rawLocation).trim();

      if (aggregatedMap.has(code)) {
        const item = aggregatedMap.get(code);
        item.qty += qty;
        if (price > 0) item.price = price;
        if (locStr && locStr !== 'N/A') {
          item.locations.add(locStr);
        }
      } else {
        const locSet = new Set();
        if (locStr && locStr !== 'N/A') {
          locSet.add(locStr);
        }
        aggregatedMap.set(code, {
          code,
          name: String(rawName).trim(),
          desc: String(rawDesc).trim(),
          qty,
          price,
          locations: locSet
        });
      }
    }

    const validRows = [];
    for (const item of aggregatedMap.values()) {
      let finalLocation = 'N/A';
      if (item.locations.size > 0) {
        finalLocation = Array.from(item.locations).join(', ');
        if (finalLocation.length > 255) {
          finalLocation = finalLocation.substring(0, 252) + '...';
        }
      }
      validRows.push({
        code: item.code,
        name: item.name,
        desc: item.desc,
        qty: item.qty,
        price: item.price,
        location: finalLocation
      });
    }

    if (validRows.length === 0) {
      console.log('No valid products to import.');
      process.exit(0);
    }

    console.log(`Prepared ${validRows.length} unique products for bulk insert...`);

    // Let's do batch insert since 6000+ rows might exceed Postgres parameter limits (max 65535 parameters)
    // 6 parameters per row, so max batch size = 10000 rows. Since we have ~6786 rows, we can do it in batches of 1000.
    const batchSize = 1000;
    let batchCount = 0;
    
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      for (let i = 0; i < validRows.length; i += batchSize) {
        const batch = validRows.slice(i, i + batchSize);
        const valuePairs = [];
        const queryParams = [];
        let paramIndex = 1;

        for (const p of batch) {
          valuePairs.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4}, $${paramIndex + 5})`);
          queryParams.push(p.code, p.name, p.desc, p.qty, p.price, p.location);
          paramIndex += 6;
        }

        const queryText = `
          INSERT INTO products (product_code, product_name, description, stock_quantity, product_price, location)
          VALUES ${valuePairs.join(', ')}
          ON CONFLICT (product_code)
          DO UPDATE SET
            product_name = EXCLUDED.product_name,
            description = EXCLUDED.description,
            stock_quantity = EXCLUDED.stock_quantity,
            product_price = EXCLUDED.product_price,
            location = EXCLUDED.location,
            updated_at = CURRENT_TIMESTAMP;
        `;

        await client.query(queryText, queryParams);
        batchCount += batch.length;
        console.log(`- Upserted batch: ${batchCount}/${validRows.length} products`);
      }

      await client.query('COMMIT');
      console.log('\n======================================');
      console.log(`✔ NEONDB STOCK CSV IMPORT COMPLETE`);
      console.log(`- Successfully Upserted (Insert/Update): ${validRows.length} unique products`);
      console.log(`======================================\n`);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('✖ Stock CSV Migration failed:', error);
  } finally {
    await pool.end();
    process.exit(0);
  }
};

importStockCSV();
