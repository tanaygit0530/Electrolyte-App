const { pool } = require('../config/neondb');

const testDb = async () => {
  try {
    console.log('Testing connection to NeonDB...');
    const timeRes = await pool.query('SELECT NOW()');
    console.log('✔ Connection Successful! Database Time:', timeRes.rows[0].now);

    console.log('Checking if tables are accessible...');
    
    const tableCheck = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);
    
    console.log('Available tables:');
    tableCheck.rows.forEach(row => {
      console.log(` - ${row.table_name}`);
    });

  } catch (error) {
    console.error('✖ Database test failed with error:');
    console.error(error);
  } finally {
    await pool.end();
    process.exit(0);
  }
};

testDb();
