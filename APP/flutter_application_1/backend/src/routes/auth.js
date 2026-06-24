const crypto = require('crypto');
const express = require('express');

const { pool } = require('../db');

const router = express.Router();

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeUsername(value) {
  return String(value || '').trim().replace(/^@+/, '').toLowerCase();
}

function splitName(fullName) {
  const normalized = String(fullName || '').trim().replace(/\s+/g, ' ');
  if (!normalized) {
    return { firstName: '', lastName: '' };
  }

  const parts = normalized.split(' ');
  const firstName = parts.shift() || '';
  const lastName = parts.join(' ').trim() || '-';

  return { firstName, lastName };
}

function buildDisplayName(firstName, lastName) {
  return [String(firstName || '').trim(), String(lastName || '').trim()]
    .filter(Boolean)
    .join(' ')
    .trim();
}

function defaultUsernameFromEmail(email) {
  const localPart = String(email || '').split('@').shift() || '';
  const normalized = localPart.toLowerCase().replace(/[^a-z0-9]/g, '');
  return normalized || `researcher${Math.floor(Math.random() * 10000)}`;
}

function hashPassword(password, salt) {
  const resolvedSalt = salt || crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, resolvedSalt, 64).toString('hex');
  return `${resolvedSalt}:${hash}`;
}

function verifyPassword(password, storedValue) {
  const stored = String(storedValue || '').trim();
  if (!stored) {
    return false;
  }

  if (!stored.includes(':')) {
    return stored === password;
  }

  const [salt, storedHash] = stored.split(':');
  if (!salt || !storedHash) {
    return false;
  }

  const computedHash = crypto.scryptSync(password, salt, 64).toString('hex');
  const a = Buffer.from(storedHash, 'hex');
  const b = Buffer.from(computedHash, 'hex');

  if (a.length !== b.length) {
    return false;
  }

  return crypto.timingSafeEqual(a, b);
}

async function loadAccountByEmail(client, email) {
  const result = await client.query(
    `SELECT
      a.account_id AS "accountId",
      a.user_id AS "userId",
      a.email,
      a.username,
      a.password,
      u.first_name AS "firstName",
      u.last_name AS "lastName",
      COALESCE(u.location, '') AS location,
      COALESCE(u.profile_photo_base64, '') AS "profilePhotoBase64",
      a.creation_date AS "createdAt"
    FROM account a
    JOIN users u ON u.user_id = a.user_id
    WHERE LOWER(a.email) = LOWER($1)
    LIMIT 1`,
    [email]
  );

  if (result.rowCount === 0) {
    return null;
  }

  return result.rows[0];
}

function toUserPayload(row) {
  return {
    accountId: Number(row.accountId),
    userId: Number(row.userId),
    name: buildDisplayName(row.firstName, row.lastName),
    email: String(row.email || ''),
    username: String(row.username || ''),
    location: String(row.location || ''),
    profilePhotoBase64: String(row.profilePhotoBase64 || ''),
    createdAt: row.createdAt,
  };
}

router.post('/signup', async (req, res, next) => {
  const name = String(req.body.name || '').trim();
  const email = normalizeEmail(req.body.email);
  const password = String(req.body.password || '');
  const requestedUsername = normalizeUsername(req.body.username);
  const location = String(req.body.location || 'Mt. Busa').trim();

  if (!name) {
    return res.status(400).json({ error: 'name is required.' });
  }

  if (!email) {
    return res.status(400).json({ error: 'email is required.' });
  }

  if (!password || password.length < 6) {
    return res
      .status(400)
      .json({ error: 'password must be at least 6 characters.' });
  }

  const username = requestedUsername || defaultUsernameFromEmail(email);
  const { firstName, lastName } = splitName(name);
  const passwordHash = hashPassword(password);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const userResult = await client.query(
      `INSERT INTO users (first_name, last_name, location)
       VALUES ($1, $2, NULLIF($3, ''))
       RETURNING user_id`,
      [firstName, lastName, location]
    );

    const userId = userResult.rows[0].user_id;
    const accountTypeResult = await client.query(
      `SELECT account_type_id FROM account_type WHERE account_desc = 'Researcher' LIMIT 1`
    );

    const accountTypeId =
      accountTypeResult.rowCount > 0
        ? accountTypeResult.rows[0].account_type_id
        : null;

    const accountResult = await client.query(
      `INSERT INTO account (user_id, email, username, password, account_type_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING account_id`,
      [userId, email, username, passwordHash, accountTypeId]
    );

    const accountId = accountResult.rows[0].account_id;

    const accountRow = await loadAccountByEmail(client, email);
    await client.query('COMMIT');

    return res.status(201).json({
      user: toUserPayload({ ...accountRow, accountId, userId }),
    });
  } catch (error) {
    await client.query('ROLLBACK');

    if (error && error.code === '23505') {
      return res.status(409).json({
        error: 'An account with the same email or username already exists.',
      });
    }

    return next(error);
  } finally {
    client.release();
  }
});

router.post('/login', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  const password = String(req.body.password || '');

  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required.' });
  }

  const client = await pool.connect();

  try {
    const account = await loadAccountByEmail(client, email);
    if (!account) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    if (!verifyPassword(password, account.password)) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    return res.json({ user: toUserPayload(account) });
  } catch (error) {
    return next(error);
  } finally {
    client.release();
  }
});

router.patch('/profile', async (req, res, next) => {
  const accountId = Number(req.body.accountId);
  const name = String(req.body.name || '').trim();
  const username = normalizeUsername(req.body.username);
  const location = String(req.body.location || '').trim();
  const profilePhotoBase64 = String(req.body.profilePhotoBase64 || '').trim();

  if (!Number.isInteger(accountId) || accountId <= 0) {
    return res.status(400).json({ error: 'accountId is required.' });
  }

  if (!name) {
    return res.status(400).json({ error: 'name is required.' });
  }

  if (!username) {
    return res.status(400).json({ error: 'username is required.' });
  }

  const { firstName, lastName } = splitName(name);
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const accountResult = await client.query(
      `SELECT account_id, user_id, email FROM account WHERE account_id = $1`,
      [accountId]
    );

    if (accountResult.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Account not found.' });
    }

    const userId = accountResult.rows[0].user_id;

    await client.query(
      `UPDATE account
       SET username = $1
       WHERE account_id = $2`,
      [username, accountId]
    );

    await client.query(
      `UPDATE users
       SET first_name = $1,
           last_name = $2,
           location = NULLIF($3, ''),
           profile_photo_base64 = NULLIF($4, '')
       WHERE user_id = $5`,
      [firstName, lastName, location, profilePhotoBase64, userId]
    );

    const updated = await loadAccountByEmail(
      client,
      accountResult.rows[0].email
    );

    await client.query('COMMIT');

    return res.json({ user: toUserPayload(updated) });
  } catch (error) {
    await client.query('ROLLBACK');

    if (error && error.code === '23505') {
      return res
        .status(409)
        .json({ error: 'That username is already taken.' });
    }

    return next(error);
  } finally {
    client.release();
  }
});

module.exports = router;
