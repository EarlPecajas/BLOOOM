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
    if (req.method === 'GET') {
      const result = await pool.query(
        `SELECT * FROM public_approved_sightings ORDER BY observation_date DESC LIMIT 100`
      );
      return res.status(200).json(result.rows);
    } else if (req.method === 'POST') {
      const payload = req.body || {};

      // Whitelist allowed columns to insert (matches backend schema)
      const allowed = new Set([
        'entry_id','user_id','researcher_email','researcher_name',
        'scientific_name','common_name','common_names','identification_confidence',
        'observation_date','observation_time','collection_method','observation_type','voucher_collected',
        'mountain_name','specific_site_zone','specific_site_other','latitude','longitude','elevation_meters',
        'habitat_type','microhabitat','growth_substrate','host_tree_species','host_tree_dbh_cm','canopy_cover_percent','light_exposure','soil_type','nearby_water_source',
        'plant_height_cm','pseudobulb_present','stem_length_cm','root_length_cm',
        'leaf_count','leaf_shape','leaf_shape_other','leaf_length_cm','leaf_width_cm','leaf_textures','leaf_arrangement',
        'flower_color','flower_count','flower_diameter_cm','inflorescence_type','petal_characteristics','sepal_characteristics','labellum_lip_description','fragrance','blooming_stage','flowering_season',
        'fruit_present','fruit_type','seed_capsule_condition',
        'life_stage','phenology','population_count','population_status','threat_level','threat_types',
        'whole_plant_photo_path','closeup_flower_photo_path','habitat_photo_path','photo_3d_path','video_path',
        'institution','team_members','researcher_notes','unusual_observations','review_status'
      ]);

      const cols = [];
      const vals = [];
      const params = [];
      let idx = 1;
      for (const key of Object.keys(payload)) {
        if (allowed.has(key) && payload[key] !== undefined) {
          cols.push(key);
          params.push(`$${idx}`);
          vals.push(payload[key]);
          idx++;
        }
      }

      if (!cols.includes('scientific_name')) {
        return res.status(400).json({ error: 'scientific_name is required' });
      }

      // Ensure entry_id exists
      if (!cols.includes('entry_id')) {
        cols.push('entry_id');
        params.push(`$${idx}`);
        vals.push((payload.entry_id) || `entry_${Date.now()}`);
        idx++;
      }

      const q = `INSERT INTO species_sightings (${cols.join(',')}) VALUES (${params.join(',')}) RETURNING *`;
      const result = await pool.query(q, vals);
      return res.status(201).json(result.rows[0]);
    }
