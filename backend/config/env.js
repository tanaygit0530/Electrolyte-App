const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
require('dotenv').config(); // Fallback to current working directory if present

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('FATAL CONFIGURATION ERROR: JWT_SECRET environment variable is missing.');
}

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.warn('WARNING: DATABASE_URL environment variable is missing.');
}

module.exports = {
  JWT_SECRET,
  PORT: process.env.PORT || 5001,
  DATABASE_URL,
  NODE_ENV: process.env.NODE_ENV || 'development',
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim())
    : ['http://localhost:3000', 'http://localhost:5173', 'https://admin.electrolyte.app']
};
