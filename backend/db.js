require('dotenv').config();

function getPgConfig() {
  const config = {
    connectionString: process.env.DATABASE_URL
  };

  if (process.env.DATABASE_SSL !== 'false') {
    config.ssl = { rejectUnauthorized: false };
  }

  return config;
}

module.exports = { getPgConfig };