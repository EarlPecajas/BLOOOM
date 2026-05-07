import { Pool } from 'pg';

// Use DATABASE_URL from .env (Session Pooler - IPv4 compatible and FREE)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: 2, // Limit connections for serverless
});

export default async function handler(req, res) {
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
    if (req.method === 'GET') {
      // Get public approved sightings
      const result = await pool.query(
        `SELECT * FROM public_approved_sightings 
         ORDER BY observation_date DESC 
         LIMIT 100`
      );
      
      return res.status(200).json(result.rows);
    } else if (req.method === 'POST') {
      // Insert new sighting
      const {
        scientific_name,
        common_name,
        elevation_meters,
        mountain_name,
        habitat_type,
        observer_name,
        observation_date
      } = req.body;

      const result = await pool.query(
        `INSERT INTO species_sightings 
         (scientific_name, common_name, elevation_meters, mountain_name, habitat_type, observer_name, observation_date)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [scientific_name, common_name, elevation_meters, mountain_name, habitat_type, observer_name, observation_date]
      );

      return res.status(201).json(result.rows[0]);
    }
  } catch (error) {
    console.error('Database error:', error);
    return res.status(500).json({ error: 'Failed to process sighting', details: error.message });
  }
}
