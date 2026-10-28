const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const { pool } = require('../config/neondb');
const { cleanupExpiredServiceRecords } = require('../controllers/serviceRecordsController');

async function executeInitialHistoricalCleanup() {
  console.log('=== INITIAL 60-DAY DATA RETENTION CLEANUP IN NEON POSTGRESQL ===\n');

  try {
    // 1. Audit before cleanup
    console.log('Step 1: Auditing operational records before cleanup...');
    const totalBefore = await pool.query('SELECT COUNT(*) FROM service_records;');
    const nullDateBefore = await pool.query('SELECT COUNT(*) FROM service_records WHERE parsed_end_date IS NULL;');
    const eligibleBefore = await pool.query(`
      SELECT COUNT(*) FROM service_records 
      WHERE parsed_end_date IS NOT NULL 
        AND parsed_end_date >= ((NOW() AT TIME ZONE 'Asia/Kolkata')::date - INTERVAL '60 days')
        AND parsed_end_date <= ((NOW() AT TIME ZONE 'Asia/Kolkata')::date + INTERVAL '1 day');
    `);
    const expiredBefore = await pool.query(`
      SELECT COUNT(*) FROM service_records 
      WHERE parsed_end_date IS NOT NULL 
        AND parsed_end_date < ((NOW() AT TIME ZONE 'Asia/Kolkata')::date - INTERVAL '60 days');
    `);

    console.log('--- Initial State ---');
    console.log(`Total Records: ${totalBefore.rows[0].count}`);
    console.log(`Eligible 60-Day Records: ${eligibleBefore.rows[0].count}`);
    console.log(`Expired (> 60 Days): ${expiredBefore.rows[0].count}`);
    console.log(`Null / Invalid Dates: ${nullDateBefore.rows[0].count}`);

    // 2. Execute authoritative cleanup
    console.log('\nStep 2: Executing cleanupExpiredServiceRecords()...');
    const result = await cleanupExpiredServiceRecords();
    console.log('Cleanup result:', result);

    // 3. Audit after cleanup
    console.log('\nStep 3: Auditing operational records after cleanup...');
    const totalAfter = await pool.query('SELECT COUNT(*) FROM service_records;');
    const expiredAfter = await pool.query(`
      SELECT COUNT(*) FROM service_records 
      WHERE parsed_end_date IS NULL 
         OR parsed_end_date < ((NOW() AT TIME ZONE 'Asia/Kolkata')::date - INTERVAL '60 days');
    `);

    console.log('--- Final State ---');
    console.log(`Total Operational Records: ${totalAfter.rows[0].count}`);
    console.log(`Expired Records Remaining: ${expiredAfter.rows[0].count}`);

    // 4. Run VACUUM ANALYZE to reclaim disk pages
    console.log('\nStep 4: Running VACUUM ANALYZE service_records to reclaim database disk space...');
    await pool.query('VACUUM ANALYZE service_records;');
    console.log('Database space reclaimed successfully.');

    console.log('\n=== RETENTION CLEANUP COMPLETE ===');

  } catch (err) {
    console.error('Error during initial cleanup:', err);
  } finally {
    await pool.end();
  }
}

executeInitialHistoricalCleanup();
