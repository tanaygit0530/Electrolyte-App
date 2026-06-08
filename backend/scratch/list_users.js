const { pool } = require('../config/neondb');

async function test() {
  try {
    const res = await pool.query('SELECT id, email, role, password_hash FROM users');
    console.log('--- USERS IN DATABASE ---');
    console.log(JSON.stringify(res.rows, null, 2));
    console.log('-------------------------');
  } catch (err) {
    console.error('Error querying database:', err);
  } finally {
    await pool.end();
  }
}

test();
