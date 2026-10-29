const { pool } = require('../config/neondb');

async function migrate() {
  console.log('--- Starting In-Place Service Records Optimization & Migration ---');

  try {
    // Step 1: In-place purge of records older than 180 days (chunked 50k to avoid locks/WAL overflow)
    console.log('1. Purging records older than 180 days in-place...');
    let totalDeleted = 0;
    while (true) {
      const res = await pool.query(`
        WITH to_delete AS (
          SELECT id FROM service_records 
          WHERE created_date < NOW() - INTERVAL '180 days'
          LIMIT 50000
        )
        DELETE FROM service_records
        WHERE id IN (SELECT id FROM to_delete);
      `);
      totalDeleted += res.rowCount;
      console.log(`   Deleted ${res.rowCount} rows (total: ${totalDeleted})...`);
      if (res.rowCount === 0) break;
    }
    console.log(`   Purged ${totalDeleted} old records successfully.`);

    // Step 2: In-place deduplication of remaining active records
    console.log('2. Deduplicating remaining active records...');
    const dedupRes = await pool.query(`
      DELETE FROM service_records a
      USING (
        SELECT MIN(ctid) as min_ctid, 
               COALESCE(TRIM(case_number), 'UNKNOWN') as c_no, 
               COALESCE(TRIM(work_order_line_item), '1') as wo_item, 
               UPPER(TRIM(serial_no)) as s_no
        FROM service_records
        WHERE serial_no IS NOT NULL AND TRIM(serial_no) != ''
        GROUP BY 
          COALESCE(TRIM(case_number), 'UNKNOWN'), 
          COALESCE(TRIM(work_order_line_item), '1'), 
          UPPER(TRIM(serial_no))
        HAVING COUNT(*) > 1
      ) b
      WHERE COALESCE(TRIM(a.case_number), 'UNKNOWN') = b.c_no
        AND COALESCE(TRIM(a.work_order_line_item), '1') = b.wo_item
        AND UPPER(TRIM(a.serial_no)) = b.s_no
        AND a.ctid > b.min_ctid;
    `);
    console.log(`   Removed ${dedupRes.rowCount} duplicate records.`);

    // Step 3: Run VACUUM to mark dead tuple pages as available
    console.log('3. Running VACUUM ANALYZE...');
    await pool.query('VACUUM ANALYZE service_records;');

    // Step 4: Add new audit columns to service_upload_history
    console.log('4. Extending service_upload_history schema...');
    await pool.query(`
      ALTER TABLE service_upload_history 
        ADD COLUMN IF NOT EXISTS valid_records integer DEFAULT 0,
        ADD COLUMN IF NOT EXISTS rejected_records integer DEFAULT 0,
        ADD COLUMN IF NOT EXISTS duplicates_in_file integer DEFAULT 0,
        ADD COLUMN IF NOT EXISTS inserted_records integer DEFAULT 0,
        ADD COLUMN IF NOT EXISTS updated_records integer DEFAULT 0,
        ADD COLUMN IF NOT EXISTS unchanged_records integer DEFAULT 0,
        ADD COLUMN IF NOT EXISTS processing_duration_ms integer DEFAULT 0,
        ADD COLUMN IF NOT EXISTS error_summary jsonb DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS status character varying(50) DEFAULT 'completed';
    `);

    // Step 5: Add is_active_60d column to service_records
    console.log('5. Adding is_active_60d column...');
    await pool.query(`
      ALTER TABLE service_records
        ADD COLUMN IF NOT EXISTS is_active_60d boolean DEFAULT false;
    `);

    // Step 6: Update is_active_60d flag
    console.log('6. Updating is_active_60d values on current records...');
    await pool.query(`
      UPDATE service_records
      SET is_active_60d = (
        parsed_end_date IS NOT NULL 
        AND parsed_end_date >= NOW() - INTERVAL '60 days' 
        AND parsed_end_date <= NOW() + INTERVAL '1 day'
      );
    `);

    // Step 7: Create composite unique index for upserts
    console.log('7. Creating unique composite index idx_service_records_composite_key...');
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_service_records_composite_key 
      ON service_records (
        case_number, 
        work_order_line_item, 
        serial_no
      );
    `);

    // Step 8: Lookup performance indexes
    console.log('8. Creating performance lookup indexes...');
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_service_records_serial_lookup
      ON service_records (UPPER(TRIM(serial_no)), parsed_end_date DESC NULLS LAST);
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_service_records_repl_serial_lookup
      ON service_records (UPPER(TRIM(replacement_serial_no)), parsed_end_date DESC NULLS LAST)
      WHERE replacement_serial_no IS NOT NULL;
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_service_records_active_60d
      ON service_records (is_active_60d)
      WHERE is_active_60d = true;
    `);

    console.log('--- Migration Completed Successfully! ---');

    // Print summary
    const countRes = await pool.query('SELECT count(*) as total, count(*) FILTER (WHERE is_active_60d = true) as active_60d FROM service_records;');
    console.log('Resulting service_records:', countRes.rows[0]);

  } catch (err) {
    console.error('Migration failed:', err);
    throw err;
  } finally {
    await pool.end();
  }
}

migrate();
