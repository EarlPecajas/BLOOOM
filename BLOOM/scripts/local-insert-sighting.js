require('dotenv').config();
const { Pool } = require('pg');

async function run() {
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
    max: 2,
  });

  const entryId = 'local-test-' + Date.now();
  const payload = {
    entry_id: entryId,
    user_id: null,
    researcher_email: 'local@test.example',
    researcher_name: 'Local Test',
    scientific_name: 'Testus orchidicus',
    common_names: JSON.stringify(['Test Orchid']),
    identification_confidence: 'Identified',
    observation_date: '2026-05-08',
    observation_time: null,
    collection_method: null,
    observation_type: 'observation',
    voucher_collected: false,
    mountain_name: 'Mt. Test',
    specific_site_zone: null,
    specific_site_other: null,
    latitude: 10.12345,
    longitude: 123.54321,
    elevation_meters: 1234,
    habitat_type: 'Forest',
    microhabitat: null,
    growth_substrate: null,
    host_tree_species: null,
    host_tree_dbh_cm: null,
    canopy_cover_percent: null,
    light_exposure: null,
    soil_type: null,
    nearby_water_source: null,
    plant_height_cm: null,
    pseudobulb_present: false,
    stem_length_cm: null,
    root_length_cm: null,
    leaf_count: null,
    leaf_shape: null,
    leaf_shape_other: null,
    leaf_length_cm: null,
    leaf_width_cm: null,
    leaf_textures: JSON.stringify([]),
    leaf_arrangement: null,
    flower_color: null,
    flower_count: null,
    flower_diameter_cm: null,
    inflorescence_type: null,
    petal_characteristics: null,
    sepal_characteristics: null,
    labellum_lip_description: null,
    fragrance: null,
    blooming_stage: null,
    fruit_present: false,
    fruit_type: null,
    seed_capsule_condition: null,
    life_stage: null,
    phenology: null,
    population_count: null,
    population_status: null,
    threat_level: null,
    threat_types: JSON.stringify([]),
    whole_plant_photo_path: null,
    closeup_flower_photo_path: null,
    habitat_photo_path: null,
    photo_3d_path: null,
    video_path: null,
    institution: null,
    team_members: null,
    researcher_notes: null,
    review_status: 'pending'
  };

  const client = await pool.connect();
  try {
    const cols = Object.keys(payload).join(', ');
    const vals = Object.keys(payload).map((k, i) => `$${i + 1}`).join(', ');
    const params = Object.keys(payload).map((k) => payload[k]);

    const q = `INSERT INTO species_sightings (${cols}) VALUES (${vals}) RETURNING *`;
    const res = await client.query(q, params);
    console.log('Inserted row:', res.rows[0]);
  } catch (err) {
    console.error('Insert failed:', err.message || err);
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch((e) => { console.error(e); process.exit(1); });
