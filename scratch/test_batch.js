const { pool } = require('../backend/config/neondb');

async function test() {
  console.log('Testing 1000 rows with 33 params...');
  const placeholders = [];
  const values = [];
  let pIdx = 1;
  for (let i = 0; i < 1000; i++) {
    const rowPlaceholders = [];
    for (let j = 0; j < 33; j++) {
      rowPlaceholders.push(`$${pIdx++}`);
      values.push(null);
    }
    placeholders.push(`(${rowPlaceholders.join(',')})`);
  }
  console.log(`Total parameters: ${values.length}`);
  try {
    const client = await pool.connect();
    console.log('Connected to pool. Trying query...');
    await client.query(`SELECT 1 FROM (VALUES ${placeholders.join(',')}) AS t(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18,a19,a20,a21,a22,a23,a24,a25,a26,a27,a28,a29,a30,a31,a32,a33) LIMIT 1`, values);
    console.log('Query succeeded!');
    client.release();
  } catch (err) {
    console.error('FAILED WITH ERROR:', err);
  } finally {
    await pool.end();
  }
}

test();
