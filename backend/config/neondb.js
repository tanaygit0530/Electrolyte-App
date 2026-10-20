const { Pool } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
require('dotenv').config();

const connectionString = (process.env.DATABASE_URL || '').trim();

if (!connectionString) {
  console.warn('WARNING: DATABASE_URL environment variable is not defined in .env. NeonDB connection will fail.');
}

const isLocalhost = connectionString && (connectionString.includes('localhost') || connectionString.includes('127.0.0.1'));

// In production, enforce certificate validation to protect against MITM attacks.
// Allow override via DB_SSL_REJECT_UNAUTHORIZED if explicitly set.
const rejectUnauthorized = process.env.DB_SSL_REJECT_UNAUTHORIZED !== undefined
  ? process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true'
  : (process.env.NODE_ENV === 'production');

const pool = new Pool({
  connectionString: connectionString,
  ssl: isLocalhost ? false : {
    rejectUnauthorized
  }
});

// Prevent backend crash on idle database connection errors/closures
pool.on('error', (err, client) => {
  console.error('Unexpected error on idle NeonDB client:', err);
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool
};
