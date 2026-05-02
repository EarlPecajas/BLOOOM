#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config();

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('Missing DATABASE_URL in .env');
  process.exit(1);
}

const pool = new Pool({ connectionString: databaseUrl });

async function runMigration(filePath) {
  try {
    const fullPath = path.join(__dirname, 'backend', filePath);
    const sql = fs.readFileSync(fullPath, 'utf8');
    
    console.log(`\n📦 Running migration: ${filePath}`);
    console.log('━'.repeat(60));
    
    const client = await pool.connect();
    try {
      await client.query(sql);
      console.log(`✅ Migration completed: ${filePath}\n`);
    } finally {
      client.release();
    }
  } catch (err) {
    console.error(`❌ Migration failed for ${filePath}:`);
    console.error(err.message);
    process.exit(1);
  }
}

async function main() {
  try {
    // Run migrations in order
    await runMigration('supabase-only.sql');
    await runMigration('assign-conservation-statuses.sql');
    
    console.log('✨ All migrations completed successfully!');
    await pool.end();
  } catch (err) {
    console.error('Fatal error:', err);
    process.exit(1);
  }
}

main();
