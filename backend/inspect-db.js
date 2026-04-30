require('dotenv').config();
const { Client } = require('pg');
const { getPgConfig } = require('./db');

async function run() {
  const client = new Client(getPgConfig());
  await client.connect();

  const tables = await client.query(
    "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') ORDER BY table_schema, table_name"
  );

  console.log('Tables:', JSON.stringify(tables.rows, null, 2));

  for (const t of tables.rows) {
    const count = await client.query(`SELECT COUNT(*)::int AS count FROM \"${t.table_schema}\".\"${t.table_name}\"`);
    console.log(`${t.table_schema}.${t.table_name}: ${count.rows[0].count}`);
  }

  await client.end();
}

run().catch((error) => {
  console.error(error.message);
  process.exit(1);
});