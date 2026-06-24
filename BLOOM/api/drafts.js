const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: 2,
});

// Columns that are written/read for a draft record.
const DRAFT_COLUMNS = [
  'entry_id', 'researcher_email', 'researcher_name', 'scientific_name',
  'genus', 'common_names', 'local_names', 'identification_confidence',
  'endemic_to_philippines',
  'observation_date', 'observation_time', 'collection_method', 'observation_type',
  'voucher_collected',
  'mountain_name', 'province', 'municipality',
  'specific_site_zone', 'specific_site_other', 'latitude', 'longitude', 'elevation_meters',
  'habitat_type', 'microhabitat', 'growth_substrate', 'host_tree_species',
  'host_tree_dbh_cm', 'canopy_cover_percent', 'light_exposure', 'soil_type',
  'nearby_water_source',
  'plant_height_cm', 'pseudobulb_present', 'stem_length_cm', 'root_length_cm',
  'leaf_count', 'leaf_shape', 'leaf_shape_other', 'leaf_length_cm', 'leaf_width_cm',
  'leaf_textures', 'leaf_arrangement',
  'flower_color', 'flower_count', 'flower_diameter_cm', 'inflorescence_type',
  'petal_characteristics', 'sepal_characteristics', 'labellum_lip_description',
  'fragrance', 'blooming_stage', 'flowering_season',
  'fruit_present', 'fruit_type', 'seed_capsule_condition',
  'life_stage', 'phenology', 'population_count', 'population_status',
  'threat_level', 'threat_types',
  'whole_plant_photo_path', 'closeup_flower_photo_path', 'habitat_photo_path',
  'institution', 'team_members', 'researcher_notes', 'related_study',
  'review_status',
  'user_uuid',
];

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    // ── GET: list drafts for a user ──────────────────────────────────────────
    if (req.method === 'GET') {
      const email = String(req.query?.email || '').trim().toLowerCase();
      const userUuid = String(req.query?.user_uuid || '').trim();

      if (!email && !userUuid) {
        return res.status(400).json({ error: 'email or user_uuid query param is required' });
      }

      let whereClause;
      const values = ['draft'];

      if (email) {
        values.push(email);
        whereClause = `WHERE lower(review_status) = $1
                         AND lower(trim(coalesce(researcher_email,''))) = $2`;
      } else {
        values.push(userUuid);
        whereClause = `WHERE lower(review_status) = $1 AND user_uuid = $2::uuid`;
      }

      const result = await pool.query(
        `SELECT sighting_id, entry_id, researcher_email, researcher_name,
                scientific_name, genus, common_names, local_names,
                identification_confidence, observation_date,
                mountain_name, province, municipality,
                latitude, longitude, elevation_meters,
                habitat_type, microhabitat, flower_color, flowering_season,
                whole_plant_photo_path, closeup_flower_photo_path, habitat_photo_path,
                review_status, researcher_notes, team_members,
                threat_level, threat_types, population_status,
                life_stage, phenology, population_count,
                created_at, updated_at
         FROM species_sightings
         ${whereClause}
         ORDER BY updated_at DESC, created_at DESC`,
        values
      );

      return res.status(200).json(result.rows);
    }

    // ── POST: create or upsert a draft ───────────────────────────────────────
    if (req.method === 'POST') {
      const payload = req.body || {};

      // Force review_status to draft.
      payload.review_status = 'draft';

      // Require the minimum identifiers.
      if (!payload.entry_id) {
        return res.status(400).json({ error: 'entry_id is required' });
      }
      if (!payload.scientific_name) {
        payload.scientific_name = 'Unknown';
      }

      // Provide safe defaults for NOT NULL columns that may not be set yet.
      if (payload.latitude === undefined || payload.latitude === null || payload.latitude === '') {
        payload.latitude = 0.0;
      }
      if (payload.longitude === undefined || payload.longitude === null || payload.longitude === '') {
        payload.longitude = 0.0;
      }
      if (!payload.identification_confidence) {
        payload.identification_confidence = 'Unidentified';
      }

      const existingId = String(req.query?.id || payload.sighting_id || '').trim();

      const columns = [];
      const vals = [];
      const placeholders = [];

      for (const col of DRAFT_COLUMNS) {
        const val = payload[col];
        if (val !== undefined) {
          columns.push(col);
          vals.push(val);
          placeholders.push(`$${vals.length}`);
        }
      }

      let result;

      if (existingId) {
        // UPDATE existing draft
        const setClauses = columns.map((c, i) => `${c} = $${i + 1}`).join(', ');
        vals.push(existingId);
        result = await pool.query(
          `UPDATE species_sightings
           SET ${setClauses}, updated_at = NOW()
           WHERE sighting_id = $${vals.length}
             AND lower(coalesce(review_status,'')) = 'draft'
           RETURNING sighting_id, entry_id, scientific_name, review_status, updated_at`,
          vals
        );

        if (result.rowCount === 0) {
          return res.status(404).json({ error: 'Draft not found' });
        }
      } else {
        // INSERT new draft (or upsert on entry_id conflict)
        const query = `
          INSERT INTO species_sightings (${columns.join(',')}, created_at, updated_at)
          VALUES (${placeholders.join(',')}, NOW(), NOW())
          ON CONFLICT (entry_id)
          DO UPDATE SET
            ${columns.filter(c => c !== 'entry_id').map(c => `${c} = EXCLUDED.${c}`).join(',\n            ')},
            updated_at = NOW()
          RETURNING sighting_id, entry_id, scientific_name, review_status, updated_at`;

        result = await pool.query(query, vals);
      }

      return res.status(200).json(result.rows[0]);
    }

    // ── DELETE: remove a draft ───────────────────────────────────────────────
    if (req.method === 'DELETE') {
      const id = String(req.query?.id || '').trim();
      const entryId = String(req.query?.entry_id || '').trim();

      if (!id && !entryId) {
        return res.status(400).json({ error: 'id or entry_id query param is required' });
      }

      let result;
      if (id) {
        result = await pool.query(
          `DELETE FROM species_sightings
           WHERE sighting_id = $1 AND lower(coalesce(review_status,'')) = 'draft'
           RETURNING sighting_id`,
          [id]
        );
      } else {
        result = await pool.query(
          `DELETE FROM species_sightings
           WHERE entry_id = $1 AND lower(coalesce(review_status,'')) = 'draft'
           RETURNING sighting_id`,
          [entryId]
        );
      }

      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Draft not found' });
      }

      return res.status(200).json({ deleted: true, sighting_id: result.rows[0].sighting_id });
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    console.error('Drafts API error:', error);
    return res.status(500).json({ error: 'Failed to process draft', details: error.message });
  }
};
