BEGIN;

CREATE TABLE IF NOT EXISTS species_sightings (
  sighting_id SERIAL PRIMARY KEY,
  entry_id VARCHAR(64) NOT NULL UNIQUE,
  user_id INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL,
  researcher_email VARCHAR(255),
  researcher_name VARCHAR(255),

  scientific_name VARCHAR(255) NOT NULL,
  common_name VARCHAR(255),
  common_names JSONB NOT NULL DEFAULT '[]'::jsonb,
  identification_confidence VARCHAR(30) NOT NULL DEFAULT 'Unidentified',

  observation_date DATE,
  observation_time TIME,
  collection_method VARCHAR(50),
  observation_type VARCHAR(50),
  voucher_collected BOOLEAN,

  mountain_name VARCHAR(120) NOT NULL DEFAULT 'Mt. Busa',
  specific_site_zone VARCHAR(120),
  specific_site_other VARCHAR(255),
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  elevation_meters NUMERIC(8, 2),

  habitat_type VARCHAR(100),
  microhabitat VARCHAR(100),
  growth_substrate VARCHAR(100),
  host_tree_species VARCHAR(255),
  host_tree_dbh_cm NUMERIC(8, 2),
  canopy_cover_percent NUMERIC(5, 2),
  light_exposure VARCHAR(50),
  soil_type VARCHAR(100),
  nearby_water_source VARCHAR(100),

  plant_height_cm NUMERIC(8, 2),
  pseudobulb_present BOOLEAN,
  stem_length_cm NUMERIC(8, 2),
  root_length_cm NUMERIC(8, 2),

  leaf_count INTEGER,
  leaf_shape VARCHAR(120),
  leaf_shape_other VARCHAR(255),
  leaf_length_cm NUMERIC(8, 2),
  leaf_width_cm NUMERIC(8, 2),
  leaf_textures JSONB NOT NULL DEFAULT '[]'::jsonb,
  leaf_arrangement VARCHAR(50),

  flower_color VARCHAR(120),
  flower_count INTEGER,
  flower_diameter_cm NUMERIC(8, 2),
  inflorescence_type VARCHAR(50),
  petal_characteristics VARCHAR(50),
  sepal_characteristics VARCHAR(255),
  labellum_lip_description VARCHAR(80),
  fragrance VARCHAR(50),
  blooming_stage VARCHAR(60),

  fruit_present BOOLEAN,
  fruit_type VARCHAR(50),
  seed_capsule_condition VARCHAR(80),

  life_stage VARCHAR(50),
  phenology VARCHAR(50),
  population_count INTEGER,

  population_status VARCHAR(50),
  threat_level VARCHAR(50),
  threat_types JSONB NOT NULL DEFAULT '[]'::jsonb,

  whole_plant_photo_path VARCHAR(255),
  closeup_flower_photo_path VARCHAR(255),
  habitat_photo_path VARCHAR(255),
  photo_3d_path VARCHAR(255),
  video_path VARCHAR(255),

  institution VARCHAR(255),
  team_members TEXT,
  researcher_notes TEXT,

  review_status VARCHAR(30) NOT NULL DEFAULT 'pending'
    CHECK (lower(review_status) IN ('approved', 'rejected', 'revision', 'pending')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_species_sightings_created_at ON species_sightings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_species_sightings_user_id ON species_sightings(user_id);
CREATE INDEX IF NOT EXISTS idx_species_sightings_review_status ON species_sightings(review_status);

COMMIT;
