const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config/env');
const { pool } = require('../config/neondb');

const requireTechnicianAuth = async (req, res, next) => {
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

    const decoded = jwt.verify(token, JWT_SECRET);
    
    if (decoded.role !== 'technician' && decoded.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: Requires technician or admin role.' });
    }

    // Server-side session & active status validation
    try {
      const activeCheck = await pool.query('SELECT is_active, role FROM users WHERE id = $1', [decoded.id]);
      if (activeCheck.rows.length > 0 && activeCheck.rows[0].is_active === false) {
        return res.status(403).json({ error: 'Account has been deactivated. Access revoked.' });
      }
    } catch (dbErr) {
      console.warn('Session DB verification warning:', dbErr.message);
    }

    // Attach user info to request
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Technician Auth Error:', error.message);
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired. Please login again.' });
    }
    return res.status(401).json({ error: 'Invalid token. Authorization failed.' });
  }
};

module.exports = { requireTechnicianAuth };
