const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
require('dotenv').config(); // Fallback to current working directory if present

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error('FATAL CONFIGURATION ERROR: JWT_SECRET environment variable is missing.');
}

const WEAK_DEFAULT_SECRETS = ['prasadinternatelectrolyte', 'secret', 'changeme', 'password', 'jwt_secret'];
if (WEAK_DEFAULT_SECRETS.includes(JWT_SECRET.toLowerCase()) || JWT_SECRET.length < 32) {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('FATAL SECURITY ERROR: JWT_SECRET is too weak or using a known default. It must be at least 32 characters (256-bit) cryptographically random string.');
  } else {
    console.warn('SECURITY WARNING: JWT_SECRET is short (<32 chars) or using a known default. Please generate a strong 256-bit secret for production.');
  }
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
