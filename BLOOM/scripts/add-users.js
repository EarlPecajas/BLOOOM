const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL || process.argv[2];
if (!connectionString) {
  console.error('Usage: DATABASE_URL="postgresql://..." node scripts/add-users.js');
  process.exit(1);
}

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

const sql = `BEGIN;

INSERT INTO account_type (account_desc) VALUES ('researcher') ON CONFLICT (account_desc) DO NOTHING;
INSERT INTO account_type (account_desc) VALUES ('denr') ON CONFLICT (account_desc) DO NOTHING;

WITH u AS (
  INSERT INTO "user" (first_name, last_name) VALUES ('Carl', 'Researcher') RETURNING user_id
), acct_type AS (
  SELECT account_type_id FROM account_type WHERE account_desc='researcher' LIMIT 1
)
INSERT INTO account (user_id, email, username, password, account_type_id)
SELECT u.user_id, 'carl@gmail.com', 'carl', '12345', acct_type.account_type_id
FROM u, acct_type
ON CONFLICT (email) DO NOTHING;

WITH u2 AS (
  INSERT INTO "user" (first_name, last_name) VALUES ('DENR', 'User') RETURNING user_id
), acct_type2 AS (
  SELECT account_type_id FROM account_type WHERE account_desc='denr' LIMIT 1
)
INSERT INTO account (user_id, email, username, password, account_type_id)
SELECT u2.user_id, 'denr@gmail.com', 'denr', '12345', acct_type2.account_type_id
FROM u2, acct_type2
ON CONFLICT (email) DO NOTHING;

COMMIT;`;

(async () => {
  try {
    await pool.query(sql);
    console.log('Users inserted (or already existed).');
  } catch (err) {
    console.error('Error running SQL:', err);
  } finally {
    await pool.end();
  }
})();
