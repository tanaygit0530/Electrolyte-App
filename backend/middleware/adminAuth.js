const jwt = require('jsonwebtoken');
require('dotenv').config();

const adminAuth = (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    if (!authHeader) {
      return res.status(401).json({ error: 'Authorization header is missing. Access denied.' });
    }

    const token = authHeader.startsWith('Bearer ') 
      ? authHeader.slice(7) 
      : authHeader;

    if (!token) {
      return res.status(401).json({ error: 'Authentication token is missing. Access denied.' });
    }

    const secret = process.env.JWT_SECRET || 'prasadinternatelectrolyte';
    const decoded = jwt.verify(token, secret);

    // Attach admin info to request
    req.admin = decoded;
    next();
  } catch (error) {
    console.error('Admin Auth Error:', error.message);
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired. Please login again.' });
    }
    return res.status(401).json({ error: 'Invalid token. Authorization failed.' });
  }
};

module.exports = adminAuth;
