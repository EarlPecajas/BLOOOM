#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false
});

async function seedOrchids() {
  const client = await pool.connect();
  try {
    const seedPath = path.join(__dirname, '..', 'backend', 'seed-genus-species.sql');
    const sql = fs.readFileSync(seedPath, 'utf8');

    console.log('Starting orchid seed process...');
    console.log(`Running SQL from: ${seedPath}`);

    // Split on semicolons and filter empty statements
    const statements = sql
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      try {
        console.log(`\n[${i + 1}/${statements.length}] Executing: ${stmt.substring(0, 80)}...`);
        const result = await client.query(stmt);
        console.log(`  ✓ Success (rows affected: ${result.rowCount})`);
      } catch (err) {
        console.error(`  ✗ Error: ${err.message}`);
        throw err;
      }
    }

    // Verify the seed
    const genusCount = await client.query('SELECT COUNT(*) as count FROM genus');
    const orchidsCount = await client.query('SELECT COUNT(*) as count FROM orchids');
    
    console.log('\n✓ Seed complete!');
    console.log(`  Genus rows: ${genusCount.rows[0].count}`);
    console.log(`  Orchids rows: ${orchidsCount.rows[0].count}`);
  } catch (error) {
    console.error('\n✗ Seed failed:', error.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

seedOrchids();
