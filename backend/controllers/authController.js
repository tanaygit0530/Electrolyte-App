const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { pool } = require('../config/neondb');
const { JWT_SECRET } = require('../config/env');
const { sendPasswordResetEmail } = require('../services/emailService');

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 30 * 60 * 1000; // 30 minutes

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

    // Check account lockout
    if (user.account_locked_until && new Date(user.account_locked_until) > new Date()) {
      const minutesRemaining = Math.ceil((new Date(user.account_locked_until) - new Date()) / (60 * 1000));
      return res.status(423).json({
        error: `Account is temporarily locked due to multiple failed login attempts. Please try again in ${minutesRemaining} minute(s) or reset your password.`
      });
    }

    if (user.is_active === false) {
      return res.status(403).json({ error: 'Your account has been deactivated or not yet approved by an Administrator.' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password_hash);

    if (!isPasswordValid) {
      const failedAttempts = (user.failed_login_attempts || 0) + 1;
      let lockedUntil = null;

      if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
        lockedUntil = new Date(Date.now() + LOCKOUT_DURATION_MS);
      }

      await pool.query(
        'UPDATE users SET failed_login_attempts = $1, account_locked_until = $2 WHERE id = $3',
        [failedAttempts, lockedUntil, user.id]
      ).catch(err => console.error('Failed to update lockout state:', err.message));

      if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
        return res.status(423).json({
          error: 'Account locked for 30 minutes due to 5 consecutive failed login attempts.'
        });
      }

      return res.status(401).json({
        error: `Invalid password. ${MAX_FAILED_ATTEMPTS - failedAttempts} attempt(s) remaining before account lockout.`
      });
    }

    // Reset failed login attempts on successful login
    if (user.failed_login_attempts > 0 || user.account_locked_until) {
      await pool.query(
        'UPDATE users SET failed_login_attempts = 0, account_locked_until = NULL WHERE id = $1',
        [user.id]
      ).catch(err => console.error('Failed to reset lockout state:', err.message));
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

/**
 * Initiates self-service password reset by generating a secure time-limited token
 */
const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || !String(email).trim()) {
      return res.status(400).json({ error: 'Please provide a valid email address.' });
    }

    const cleanEmail = String(email).trim().toLowerCase();
    const userRes = await pool.query('SELECT id, email, name FROM users WHERE LOWER(email) = $1', [cleanEmail]);
    const user = userRes.rows[0];

    // Generic response regardless of whether user exists to prevent email enumeration
    const genericResponse = {
      message: 'If an account with that email exists, password reset instructions have been sent.'
    };

    if (!user) {
      return res.status(200).json(genericResponse);
    }

    const resetToken = crypto.randomBytes(24).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    await pool.query(
      'UPDATE users SET reset_password_token = $1, reset_password_expires = $2 WHERE id = $3',
      [resetToken, expiresAt, user.id]
    );

    try {
      await sendPasswordResetEmail(user.email, resetToken);
    } catch (emailErr) {
      console.error('Password reset email dispatch failure:', emailErr.message);
      // Return 200 with guidance so client flow does not crash
      return res.status(200).json({
        message: 'Password reset token generated. Please check your email or contact support.'
      });
    }

    return res.status(200).json(genericResponse);
  } catch (error) {
    console.error('forgotPassword error:', error);
    return res.status(500).json({ error: 'Failed to process password reset request.' });
  }
};

/**
 * Completes password reset given a valid verification token
 */
const resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      return res.status(400).json({ error: 'Reset token and new password are required.' });
    }

    if (String(newPassword).length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters long.' });
    }

    const userRes = await pool.query(
      'SELECT id, email FROM users WHERE reset_password_token = $1 AND reset_password_expires > NOW()',
      [token.trim()]
    );
    const user = userRes.rows[0];

    if (!user) {
      return res.status(400).json({ error: 'Password reset token is invalid or has expired.' });
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);

    await pool.query(
      `UPDATE users 
       SET password_hash = $1, 
           reset_password_token = NULL, 
           reset_password_expires = NULL,
           failed_login_attempts = 0,
           account_locked_until = NULL 
       WHERE id = $2`,
      [passwordHash, user.id]
    );

    return res.status(200).json({ message: 'Password has been reset successfully. You can now log in.' });
  } catch (error) {
    console.error('resetPassword error:', error);
    return res.status(500).json({ error: 'Failed to reset password.' });
  }
};

/**
 * Allows authenticated technicians and admins to change their own password
 */
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ error: 'Authentication required.' });
    }

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current password and new password are required.' });
    }

    if (String(newPassword).length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters long.' });
    }

    const userRes = await pool.query('SELECT id, password_hash FROM users WHERE id = $1', [userId]);
    const user = userRes.rows[0];

    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isMatch) {
      return res.status(400).json({ error: 'Current password does not match.' });
    }

    const newHash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [newHash, userId]);

    return res.status(200).json({ message: 'Password changed successfully.' });
  } catch (error) {
    console.error('changePassword error:', error);
    return res.status(500).json({ error: 'Failed to change password.' });
  }
};

module.exports = {
  login,
  forgotPassword,
  resetPassword,
  changePassword
};
