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
      // Legacy seed sightings predate the 3NF split (sighting_morphology / sighting_habitat /
      // sighting_conservation) and were never linked to those sub-tables, so the view's join
      // columns come back null for them even though the original data still sits in flat
      // columns on species_sightings. Coalesce those in here (view stays untouched) so both
      // old seed data and new normalized submissions render correctly.
      const result = await pool.query(
        `SELECT pas.*,
           coalesce(pas.leaf_shape, s.leaf_shape)                         AS leaf_shape,
           coalesce(pas.leaf_arrangement, s.leaf_arrangement)             AS leaf_arrangement,
           coalesce(pas.flower_color, s.flower_color)                    AS flower_color,
           coalesce(pas.inflorescence_type, s.inflorescence_type)        AS inflorescence_type,
           coalesce(pas.petal_characteristics, s.petal_characteristics)  AS petal_characteristics,
           coalesce(pas.labellum_lip_description, s.labellum_description) AS labellum_lip_description,
           coalesce(pas.fragrance, s.fragrance)                          AS fragrance,
           coalesce(pas.fruit_type, s.fruit_type)                        AS fruit_type,
           coalesce(pas.habitat_type, s.habitat_type)                    AS habitat_type,
           coalesce(pas.microhabitat, s.microhabitat)                    AS microhabitat,
           coalesce(pas.growth_substrate, s.growth_substrate)            AS growth_substrate,
           coalesce(pas.nearby_water_source, s.nearby_water_source)      AS nearby_water_source,
           coalesce(pas.population_status, s.population_status)          AS population_status,
           coalesce(pas.threat_level, s.threat_level)                    AS threat_level,
           coalesce(nullif(pas.threat_level_generalized, ''), s.threat_level, '') AS threat_level_generalized,
           s.plant_height                                                AS plant_height_legacy,
           s.flower_diameter                                             AS flower_diameter_legacy,
           s.leaf_texture                                                AS leaf_texture_legacy,
           s.fruit_present                                               AS fruit_present_legacy
         FROM public_approved_sightings pas
         JOIN species_sightings s ON s.sighting_id = pas.id
         ORDER BY lower(trim(pas.scientific_name)), pas.observation_date DESC NULLS LAST, pas.id DESC`
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
        'institution', 'team_members', 'researcher_notes', 'review_status'
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
