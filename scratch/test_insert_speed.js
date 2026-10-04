const { pool } = require('../backend/config/neondb');

async function testSpeed() {
  const client = await pool.connect();
  try {
    console.log('Connected to NeonDB. Starting speed test...');
    for (let b = 0; b < 3; b++) {
      const t0 = Date.now();
      const placeholders = [];
      const values = [];
      let pIdx = 1;
      for (let i = 0; i < 1000; i++) {
        const row = [];
        for (let j = 0; j < 33; j++) {
          row.push(`$${pIdx++}`);
          if (j === 1 || j === 15) {
            values.push(new Date());
          } else if (j === 29) {
            values.push(`TEST_SERIAL_${b}_${i}`);
          } else {
            values.push('test_val');
          }
        }
        placeholders.push(`(${row.join(',')})`);
      }
      const q = `INSERT INTO service_records (
        case_number, created_date, work_order_line_item, customer_name, service_territory,
        street, city, state, zip_code, customer_complaint,
        wo_status, symptom, defect, repair, end_date,
        parsed_end_date, days, product_code, product_name, product_description,
        product_type, product_sub_type, warranty_status, type_of_work_order, line_item_status,
        sdr_status, invoice_date, technician_name, technician_remarks, serial_no,
        replacement_serial_no, type_of_resolution, closed_date
      ) VALUES ${placeholders.join(', ')}`;
      
      await client.query(q, values);
      console.log(`Batch ${b + 1} (1000 rows, 33000 params) took ${(Date.now() - t0)/1000}s`);
    }
  } catch (e) {
    console.error('Error in batch test:', e);
  } finally {
    // Clean up test rows
    await client.query("DELETE FROM service_records WHERE serial_no LIKE 'TEST_SERIAL_%'");
    client.release();
    await pool.end();
  }
}

testSpeed();
