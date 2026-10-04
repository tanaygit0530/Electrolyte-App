const { pool } = require('../backend/config/neondb');

async function testTypes() {
  const client = await pool.connect();
  try {
    const dates = [new Date(), null, new Date(Date.now() - 86400000)];
    const texts = ['SERIAL1', 'SERIAL2', 'SERIAL3'];
    const res = await client.query(`
      SELECT * FROM UNNEST($1::text[], $2::timestamptz[]) AS t(serial, end_date)
    `, [texts, dates]);
    console.log('Result:', res.rows);
  } catch (e) {
    console.error('Type error:', e);
  } finally {
    client.release();
    await pool.end();
  }
}

testTypes();
