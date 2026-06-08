const jwt = require('jsonwebtoken');

const requireTechnicianAuth = (req, res, next) => {
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
    
    if (decoded.role !== 'technician') {
      return res.status(403).json({ error: 'Forbidden: Requires technician role.' });
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
