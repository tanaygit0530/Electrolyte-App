const { pool } = require('../config/neondb');

const testStockUpload = async () => {
  const client = await pool.connect();
  try {
    console.log('Beginning simulated transaction...');
    await client.query('BEGIN');

    const productCode = 'EA01701';
    const qty = 12;
    const fileName = 'test_stock.xlsx';
    const uploadedBy = 'admin@electrolyte.com';
    const totalRows = 1;
    let updatedRows = 0;
    let failedRows = 0;

    console.log(`Checking product existence for code: ${productCode}`);
    const prodCheck = await client.query('SELECT id FROM products WHERE product_code = $1', [productCode]);
    if (prodCheck.rows.length === 0) {
      console.log('Product not found!');
      failedRows++;
    } else {
      console.log(`Product found with ID: ${prodCheck.rows[0].id}. Updating...`);
      const updateRes = await client.query(
        'UPDATE products SET stock_quantity = $1, updated_at = CURRENT_TIMESTAMP WHERE product_code = $2',
        [qty, productCode]
      );
      console.log(`Update result rows affected: ${updateRes.rowCount}`);
      updatedRows++;
    }

    console.log('Inserting into stock_upload_history...');
    const historyRes = await client.query(
      'INSERT INTO stock_upload_history (file_name, uploaded_by, total_rows, updated_rows, failed_rows) VALUES ($1, $2, $3, $4, $5)',
      [fileName, uploadedBy, totalRows, updatedRows, failedRows]
    );
    console.log('History insert successful!');

    await client.query('COMMIT');
    console.log('✔ Simulated Transaction Committed Successfully!');
  } catch (error) {
    console.error('✖ Simulated Transaction Failed with error:');
    console.error(error);
    try {
      await client.query('ROLLBACK');
      console.log('Rollback complete.');
    } catch (rbError) {
      console.error('Error during rollback:', rbError);
    }
  } finally {
    client.release();
    await pool.end();
    process.exit(0);
  }
};

testStockUpload();
