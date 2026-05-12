BEGIN;

-- Reset incompatible legacy orchid-domain tables so ERD tables can be created consistently.
DROP TABLE IF EXISTS species_image CASCADE;
DROP TABLE IF EXISTS species CASCADE;
DROP TABLE IF EXISTS biogeography CASCADE;
DROP TABLE IF EXISTS orchids CASCADE;
DROP TABLE IF EXISTS habitat_information CASCADE;
DROP TABLE IF EXISTS picture CASCADE;
DROP TABLE IF EXISTS specie_value CASCADE;
DROP TABLE IF EXISTS morphological_characteristics CASCADE;
DROP TABLE IF EXISTS conservation_status CASCADE;

CREATE TABLE IF NOT EXISTS account_type (
  account_type_id SERIAL PRIMARY KEY,
  account_desc VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS affiliation (
  affiliation_id SERIAL PRIMARY KEY,
  affiliation VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS province (
  province_id SERIAL PRIMARY KEY,
  province_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS municipality (
  municipality_id SERIAL PRIMARY KEY,
  province_id INTEGER NOT NULL REFERENCES province(province_id) ON DELETE RESTRICT,
  municipality_name VARCHAR(255) NOT NULL,
  coordinates VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS mountain (
  mountain_id SERIAL PRIMARY KEY,
  municipality_id INTEGER NOT NULL REFERENCES municipality(municipality_id) ON DELETE RESTRICT,
  mountain_name VARCHAR(255) NOT NULL,
  coordinates VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS location (
  location_id SERIAL PRIMARY KEY,
  mountain_id INTEGER NOT NULL REFERENCES mountain(mountain_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS address (
  address_id SERIAL PRIMARY KEY,
  municipality_id INTEGER REFERENCES municipality(municipality_id) ON DELETE SET NULL,
  city_name VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS "user" (
  user_id SERIAL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  gender_id VARCHAR(50),
  address_id INTEGER REFERENCES address(address_id) ON DELETE SET NULL,
  affiliation_id INTEGER REFERENCES affiliation(affiliation_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS account (
  account_id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES "user"(user_id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  username VARCHAR(255) UNIQUE,
  password VARCHAR(255) NOT NULL,
  account_type_id INTEGER REFERENCES account_type(account_type_id) ON DELETE SET NULL,
  creation_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS genus (
  genus_id SERIAL PRIMARY KEY,
  genus_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS conservation_status (
  conservation_id SERIAL PRIMARY KEY,
  conservation_status VARCHAR(255),
  status_desc VARCHAR(255),
  threats VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS morphological_characteristics (
  morphological_id SERIAL PRIMARY KEY,
  leaf_type VARCHAR(255),
  flower_color VARCHAR(255),
  flowering_season VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS specie_value (
  specie_val_id SERIAL PRIMARY KEY,
  ethnobotanical VARCHAR(255),
  horticulture_value VARCHAR(255),
  cultural_imp VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS picture (
  picture_id SERIAL PRIMARY KEY,
  file_name VARCHAR(255),
  file_path VARCHAR(255) NOT NULL UNIQUE,
  file_type VARCHAR(100),
  file_size INTEGER,
  date_uploaded TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS habitat_information (
  habitat_id SERIAL PRIMARY KEY,
  location_id INTEGER REFERENCES location(location_id) ON DELETE SET NULL,
  elevation VARCHAR(255),
  altitude VARCHAR(255),
  vertical_distribution VARCHAR(255),
  habitat_type VARCHAR(255),
  micro_habitat VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS orchids (
  orchid_id SERIAL PRIMARY KEY,
  sci_name VARCHAR(255) NOT NULL UNIQUE,
  genus_id INTEGER NOT NULL REFERENCES genus(genus_id) ON DELETE RESTRICT,
  common_name VARCHAR(255),
  endemicity VARCHAR(255),
  date_discovered TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS biogeography (
  biogeographic_id SERIAL PRIMARY KEY,
  orchid_id INTEGER UNIQUE REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  habitat_id INTEGER REFERENCES habitat_information(habitat_id) ON DELETE SET NULL,
  conservation_id INTEGER REFERENCES conservation_status(conservation_id) ON DELETE SET NULL,
  picture_id INTEGER REFERENCES picture(picture_id) ON DELETE SET NULL,
  user_id INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL,
  morphological_id INTEGER REFERENCES morphological_characteristics(morphological_id) ON DELETE SET NULL,
  specie_val_id INTEGER REFERENCES specie_value(specie_val_id) ON DELETE SET NULL,
  submission_status VARCHAR(30) NOT NULL DEFAULT 'pending'
    CHECK (lower(submission_status) IN ('approved', 'rejected', 'revision', 'pending'))
);

-- Legacy table kept for compatibility with the current login/register code.
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  birth_date DATE,
  phone VARCHAR(30),
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS species_sightings (
  sighting_id SERIAL PRIMARY KEY,
  entry_id VARCHAR(64) NOT NULL UNIQUE,
  user_id INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL,
  researcher_email VARCHAR(255),
  researcher_name VARCHAR(255),

  scientific_name VARCHAR(255) NOT NULL,
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
  flowering_season VARCHAR(60),

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

CREATE INDEX IF NOT EXISTS idx_orchids_genus_id ON orchids(genus_id);
CREATE INDEX IF NOT EXISTS idx_biogeography_orchid_id ON biogeography(orchid_id);
CREATE INDEX IF NOT EXISTS idx_account_user_id ON account(user_id);
CREATE INDEX IF NOT EXISTS idx_municipality_province_id ON municipality(province_id);
CREATE INDEX IF NOT EXISTS idx_mountain_municipality_id ON mountain(municipality_id);
CREATE INDEX IF NOT EXISTS idx_species_sightings_created_at ON species_sightings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_species_sightings_user_id ON species_sightings(user_id);
CREATE INDEX IF NOT EXISTS idx_species_sightings_review_status ON species_sightings(review_status);

INSERT INTO account_type (account_desc)
VALUES ('admin'), ('researcher'), ('user')
ON CONFLICT (account_desc) DO NOTHING;

COMMIT;