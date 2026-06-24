const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL || process.argv[2];
if (!connectionString) {
  console.error('Usage: DATABASE_URL="postgresql://..." node scripts/list-users.js');
  process.exit(1);
}

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

(async () => {
  try {
    const res = await pool.query(`
      SELECT a.email, a.username, at.account_desc, u.first_name, u.last_name
      FROM account a
      LEFT JOIN account_type at ON a.account_type_id = at.account_type_id
      LEFT JOIN "user" u ON a.user_id = u.user_id
      WHERE a.email IN ('carl@gmail.com','denr@gmail.com')
    `);
    console.log(JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error('Error querying:', err.message || err);
  } finally {
    await pool.end();
  }
})();
