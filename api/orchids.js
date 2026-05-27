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
    const { id } = req.query;

    if (id) {
      // Get specific orchid
      const result = await pool.query(
        'SELECT * FROM orchid_overview WHERE id = $1',
        [id]
      );
      
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Orchid not found' });
      }
      
      return res.status(200).json(result.rows[0]);
    } else {
      // Get all orchids with conservation status from the most recent approved sighting
      const result = await pool.query(
        `SELECT
           o.id, o.name, o.genus, o.common_name, o.endemicity, o.image_url,
           (SELECT s.threat_level
            FROM species_sightings s
            WHERE LOWER(TRIM(s.scientific_name)) = LOWER(TRIM(o.name))
              AND s.review_status = 'approved'
              AND s.threat_level IS NOT NULL
              AND s.threat_level <> ''
            ORDER BY s.observation_date DESC NULLS LAST, s.id DESC
            LIMIT 1) AS conservation_status
         FROM orchid_overview o
         ORDER BY o.name ASC`
      );

      return res.status(200).json(result.rows);
    }
  } catch (error) {
    console.error('Database error:', error);
    return res.status(500).json({ error: 'Failed to fetch orchids', details: error.message });
  }
};
