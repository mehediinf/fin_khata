const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const { pool } = require('../db');

const router = express.Router();

const ACCESS_TOKEN_TTL_SECONDS = 15 * 60; // 15 minutes
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function issueAccessToken(userId) {
  return jwt.sign({ sub: userId }, process.env.JWT_ACCESS_SECRET, {
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
  });
}

async function issueRefreshToken(userId) {
  const rawToken = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [userId, hashToken(rawToken), expiresAt],
  );
  return rawToken;
}

function validateCredentials(email, password) {
  if (typeof email !== 'string' || !EMAIL_RE.test(email)) {
    return 'A valid email is required.';
  }
  if (typeof password !== 'string' || password.length < 8) {
    return 'Password must be at least 8 characters.';
  }
  return null;
}

router.post('/register', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    const validationError = validateCredentials(email, password);
    if (validationError) return res.status(400).json({ error: validationError });

    const normalizedEmail = email.trim().toLowerCase();
    const existing = await pool.query('SELECT id FROM users WHERE email=$1', [normalizedEmail]);
    if (existing.rows.length) {
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const inserted = await pool.query(
      'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email',
      [normalizedEmail, passwordHash],
    );
    const user = inserted.rows[0];

    const accessToken = issueAccessToken(user.id);
    const refreshToken = await issueRefreshToken(user.id);
    res.status(201).json({ user: { id: user.id, email: user.email }, accessToken, refreshToken });
  } catch (err) {
    next(err);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    if (typeof email !== 'string' || typeof password !== 'string') {
      return res.status(400).json({ error: 'Email and password are required.' });
    }
    const normalizedEmail = email.trim().toLowerCase();
    const result = await pool.query(
      'SELECT id, email, password_hash FROM users WHERE email=$1',
      [normalizedEmail],
    );
    const user = result.rows[0];
    const passwordMatches = user ? await bcrypt.compare(password, user.password_hash) : false;
    if (!user || !passwordMatches) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const accessToken = issueAccessToken(user.id);
    const refreshToken = await issueRefreshToken(user.id);
    res.json({ user: { id: user.id, email: user.email }, accessToken, refreshToken });
  } catch (err) {
    next(err);
  }
});

router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {};
    if (typeof refreshToken !== 'string' || !refreshToken) {
      return res.status(400).json({ error: 'refreshToken is required.' });
    }
    const tokenHash = hashToken(refreshToken);
    const result = await pool.query(
      'SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash=$1',
      [tokenHash],
    );
    const row = result.rows[0];
    if (!row) return res.status(401).json({ error: 'Invalid refresh token.' });

    if (row.revoked_at) {
      // Reuse of an already-revoked token: possible theft. Revoke every
      // outstanding refresh token for this user as a defensive measure.
      await pool.query(
        'UPDATE refresh_tokens SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL',
        [row.user_id],
      );
      return res.status(401).json({ error: 'Refresh token has already been used. Please log in again.' });
    }
    if (new Date(row.expires_at).getTime() < Date.now()) {
      return res.status(401).json({ error: 'Refresh token has expired. Please log in again.' });
    }

    await pool.query('UPDATE refresh_tokens SET revoked_at=now() WHERE id=$1', [row.id]);
    const accessToken = issueAccessToken(row.user_id);
    const newRefreshToken = await issueRefreshToken(row.user_id);
    res.json({ accessToken, refreshToken: newRefreshToken });
  } catch (err) {
    next(err);
  }
});

router.post('/logout', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {};
    if (typeof refreshToken === 'string' && refreshToken) {
      await pool.query(
        'UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1 AND revoked_at IS NULL',
        [hashToken(refreshToken)],
      );
    }
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
