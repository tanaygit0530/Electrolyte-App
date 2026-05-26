const { pool } = require('../config/neondb');

const countProducts = async () => {
  try {
    const res = await pool.query('SELECT COUNT(*) FROM products');
    console.log(`CURRENT_COUNT:${res.rows[0].count}`);
  } catch (err) {
    console.error('Error counting products:', err.message);
  } finally {
    await pool.end();
    process.exit(0);
  }
};

countProducts();
