const { Pool } = require('pg');

// Use DATABASE_URL from .env (Session Pooler - IPv4 compatible and FREE)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: 2, // Limit connections for serverless
});

module.exports = async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version');
  
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    const { name } = req.query;

    if (name) {
      // Get DENR sightings for specific species
      const result = await pool.query(
        `SELECT * FROM denr_approved_sightings 
         WHERE scientific_name = $1
         ORDER BY observation_date DESC
         LIMIT 1`,
        [name]
      );
      
      return res.status(200).json(result.rows);
    } else {
      // Get all DENR sightings
      const result = await pool.query(
        `SELECT * FROM denr_approved_sightings 
         ORDER BY observation_date DESC 
         LIMIT 100`
      );
      
      return res.status(200).json(result.rows);
    }
  } catch (error) {
    console.error('Database error:', error);
    return res.status(500).json({ error: 'Failed to fetch DENR sightings', details: error.message });
  }
};
