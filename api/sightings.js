const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: 2,
});

module.exports = async function handler(req, res) {
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
      const result = await pool.query(
        `SELECT DISTINCT ON (lower(trim(scientific_name)))
           *
         FROM public_approved_sightings
         ORDER BY lower(trim(scientific_name)), observation_date DESC NULLS LAST, id DESC`
      );
      return res.status(200).json(result.rows);
    }

    if (req.method === 'POST') {
      const payload = req.body || {};

      const allowed = new Set([
        'entry_id', 'user_id', 'researcher_email', 'researcher_name',
        'scientific_name', 'common_name', 'common_names', 'identification_confidence',
        'observation_date', 'observation_time', 'collection_method', 'observation_type', 'voucher_collected',
        'mountain_name', 'specific_site_zone', 'specific_site_other', 'latitude', 'longitude', 'elevation_meters',
        'habitat_type', 'microhabitat', 'growth_substrate', 'host_tree_species', 'host_tree_dbh_cm', 'canopy_cover_percent', 'light_exposure', 'soil_type', 'nearby_water_source',
        'plant_height_cm', 'pseudobulb_present', 'stem_length_cm', 'root_length_cm',
        'leaf_count', 'leaf_shape', 'leaf_shape_other', 'leaf_length_cm', 'leaf_width_cm', 'leaf_textures', 'leaf_arrangement',
        'flower_color', 'flower_count', 'flower_diameter_cm', 'inflorescence_type', 'petal_characteristics', 'sepal_characteristics', 'labellum_lip_description', 'fragrance', 'blooming_stage',
        'fruit_present', 'fruit_type', 'seed_capsule_condition',
        'life_stage', 'phenology', 'population_count', 'population_status', 'threat_level', 'threat_types',
        'whole_plant_photo_path', 'closeup_flower_photo_path', 'habitat_photo_path', 'photo_3d_path', 'video_path',
        'institution', 'team_members', 'researcher_notes', 'unusual_observations', 'review_status'
      ]);

      const columns = [];
      const values = [];
      const placeholders = [];

      for (const [key, value] of Object.entries(payload)) {
        if (allowed.has(key) && value !== undefined) {
          columns.push(key);
          values.push(value);
          placeholders.push(`$${values.length}`);
        }
      }

      if (!columns.includes('scientific_name')) {
        return res.status(400).json({ error: 'scientific_name is required' });
      }

      if (!columns.includes('entry_id')) {
        columns.push('entry_id');
        values.push(`entry_${Date.now()}`);
        placeholders.push(`$${values.length}`);
      }

      const query = `INSERT INTO species_sightings (${columns.join(',')}) VALUES (${placeholders.join(',')}) RETURNING *`;
      const result = await pool.query(query, values);
      return res.status(201).json(result.rows[0]);
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    console.error('Database error:', error);
    return res.status(500).json({ error: 'Failed to process sighting', details: error.message });
  }
};
