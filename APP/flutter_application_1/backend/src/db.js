const { Pool } = require('pg');

function parseBooleanFlag(value) {
  const normalized = (value || '').toString().trim().toLowerCase();

  if (!normalized) {
    return null;
  }

  if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
    return true;
  }

  if (normalized === 'false' || normalized === '0' || normalized === 'no') {
    return false;
  }

  return null;
}

function resolveSslConfig({ connectionString, host }) {
  const explicitSsl = parseBooleanFlag(process.env.DB_SSL);
  const explicitRejectUnauthorized = parseBooleanFlag(
    process.env.DB_SSL_REJECT_UNAUTHORIZED
  );

  const hasSupabaseHost =
    connectionString.includes('supabase.co') || host.includes('supabase.co');
  const sslModeRequired = /sslmode=require/i.test(connectionString);

  const useSsl =
    explicitSsl !== null ? explicitSsl : hasSupabaseHost || sslModeRequired;

  if (!useSsl) {
    return undefined;
  }

  return {
    // Keep TLS verification on by default; override only when needed.
    rejectUnauthorized:
      explicitRejectUnauthorized !== null ? explicitRejectUnauthorized : true,
  };
}

function resolvePoolConfig() {
  const connectionString = (
    process.env.DATABASE_URL ||
    process.env.SUPABASE_DB_URL ||
    ''
  ).trim();
  const host = process.env.DB_HOST || 'localhost';
  const ssl = resolveSslConfig({ connectionString, host });

  if (connectionString) {
    return {
      connectionString,
      ...(ssl ? { ssl } : {}),
    };
  }

  return {
    host,
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'bloom_gis',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    ...(ssl ? { ssl } : {}),
  };
}

const pool = new Pool({
  ...resolvePoolConfig(),
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('Unexpected PostgreSQL error:', err);
});

async function query(text, params = []) {
  return pool.query(text, params);
}

async function testConnection() {
  const result = await query(
    `
      SELECT
        NOW() AS now,
        EXISTS (
          SELECT 1
          FROM pg_extension
          WHERE extname = 'postgis'
        ) AS postgis_enabled
    `
  );

  return {
    now: result.rows[0]?.now,
    postgisEnabled: result.rows[0]?.postgis_enabled === true,
  };
}

module.exports = {
  pool,
  query,
  testConnection,
};
