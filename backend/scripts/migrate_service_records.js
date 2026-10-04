const { pool } = require('../config/neondb');

async function migrate() {
  const client = await pool.connect();
  try {
    console.log('Beginning database migration for service_records...');
    await client.query('BEGIN');

    // Create service_records table
    await client.query(`
      CREATE TABLE IF NOT EXISTS service_records (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        case_number VARCHAR(128),
        created_date TIMESTAMP WITH TIME ZONE,
        work_order_line_item VARCHAR(64),
        customer_name VARCHAR(255),
        service_territory VARCHAR(255),
        street TEXT,
        city VARCHAR(128),
        state VARCHAR(128),
        zip_code VARCHAR(64),
        customer_complaint TEXT,
        wo_status VARCHAR(128),
        symptom TEXT,
        defect TEXT,
        repair TEXT,
        end_date VARCHAR(128),
        parsed_end_date TIMESTAMP WITH TIME ZONE,
        days VARCHAR(64),
        product_code VARCHAR(128),
        product_name VARCHAR(255),
        product_description TEXT,
        product_type VARCHAR(128),
        product_sub_type VARCHAR(128),
        warranty_status VARCHAR(128),
        type_of_work_order VARCHAR(128),
        line_item_status VARCHAR(128),
        sdr_status VARCHAR(128),
        invoice_date VARCHAR(128),
        technician_name VARCHAR(255),
        technician_remarks TEXT,
        serial_no VARCHAR(128) NOT NULL,
        replacement_serial_no VARCHAR(128),
        type_of_resolution VARCHAR(128),
        closed_date VARCHAR(128),
        parsed_closed_date TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
    `);

    // Create indexes for sub-millisecond query performance
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_service_records_serial_no 
      ON service_records (UPPER(TRIM(serial_no)));
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_service_records_repl_serial 
      ON service_records (UPPER(TRIM(replacement_serial_no))) 
      WHERE replacement_serial_no IS NOT NULL;
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_service_records_created_date 
      ON service_records (created_date DESC);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_service_records_parsed_end_date 
      ON service_records (parsed_end_date DESC);
    `);

    // Create service_upload_history table
    await client.query(`
      CREATE TABLE IF NOT EXISTS service_upload_history (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        file_name VARCHAR(255) NOT NULL,
        uploaded_by VARCHAR(255) NOT NULL,
        total_records INTEGER NOT NULL DEFAULT 0,
        found_within_60_days INTEGER NOT NULL DEFAULT 0,
        older_than_60_days INTEGER NOT NULL DEFAULT 0,
        uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
    `);

    await client.query('COMMIT');
    console.log('Migration completed successfully! Tables and indexes ready.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
    process.exit(0);
  }
}

migrate();
