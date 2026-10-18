const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/neondb');
const { JWT_SECRET } = require('../config/env');

const login = async (req, res) => {
  try {
    const identifier = req.body.email || req.body.identifier || req.body.id;
    const { password } = req.body;

    if (!identifier || !password) {
      return res.status(400).json({ error: 'Please enter a Technician ID / Email and password' });
    }

    const cleanIdentifier = String(identifier).trim();

    // Query user by email (case-insensitive) OR technician_id (case-insensitive)
    const userQuery = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = LOWER($1) OR UPPER(technician_id) = UPPER($1)',
      [cleanIdentifier]
    );
    const user = userQuery.rows[0];

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials. No user found.' });
    }

    if (user.is_active === false) {
      return res.status(403).json({ error: 'Your account has been deactivated or not yet approved by an Administrator.' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password_hash);

    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid password' });
    }

    const token = jwt.sign(
      {
        id: user.id,
        email: user.email,
        role: user.role,
        name: user.name || 'Technician',
        technicianId: user.technician_id
      },
      JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '12h' }
    );

    res.json({
      message: 'Logged in successfully',
      token,
      user: {
        id: user.id,
        name: user.name || 'Technician',
        technicianId: user.technician_id,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isActive: user.is_active
      }
    });

  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

module.exports = { login };
