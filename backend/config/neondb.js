const { Pool } = require('pg');
require('dotenv').config();

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.warn('WARNING: DATABASE_URL environment variable is not defined in .env. NeonDB connection will fail.');
}

const pool = new Pool({
  connectionString: connectionString,
  ssl: {
    rejectUnauthorized: false // NeonDB requires SSL connection
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
