require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const { getPgConfig } = require('./db');

async function run() {
  const sqlPath = process.argv[2];

  if (!sqlPath) {
    throw new Error('Usage: node run-sql-file.js <sql-file>');
  }

  const absolutePath = path.resolve(process.cwd(), sqlPath);
  const sql = fs.readFileSync(absolutePath, 'utf8');

  const client = new Client(getPgConfig());
  await client.connect();
  await client.query(sql);
  await client.end();

  console.log(`Applied SQL: ${sqlPath}`);
}

run().catch((error) => {
  console.error(error.message);
  process.exit(1);
});