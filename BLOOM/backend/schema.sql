BEGIN;

-- Reset orchid-domain tables so the 3NF schema can be created consistently.
DROP TABLE IF EXISTS sighting_media       CASCADE;
DROP TABLE IF EXISTS sighting_team_member CASCADE;
DROP TABLE IF EXISTS sighting_conservation CASCADE;
DROP TABLE IF EXISTS sighting_morphology  CASCADE;
DROP TABLE IF EXISTS sighting_habitat     CASCADE;
DROP TABLE IF EXISTS species_sightings    CASCADE;
DROP TABLE IF EXISTS biogeography         CASCADE;
DROP TABLE IF EXISTS orchids              CASCADE;
DROP TABLE IF EXISTS habitat_information  CASCADE;
DROP TABLE IF EXISTS morphological_characteristics CASCADE;
DROP TABLE IF EXISTS specie_value         CASCADE;
DROP TABLE IF EXISTS picture              CASCADE;
DROP TABLE IF EXISTS conservation_status  CASCADE;
DROP TABLE IF EXISTS genus                CASCADE;
DROP TABLE IF EXISTS account              CASCADE;
DROP TABLE IF EXISTS "user"               CASCADE;
DROP TABLE IF EXISTS gender               CASCADE;
DROP TABLE IF EXISTS address              CASCADE;
DROP TABLE IF EXISTS mountain             CASCADE;
DROP TABLE IF EXISTS municipality         CASCADE;
DROP TABLE IF EXISTS province             CASCADE;
DROP TABLE IF EXISTS location             CASCADE;
DROP TABLE IF EXISTS affiliation          CASCADE;
DROP TABLE IF EXISTS account_type         CASCADE;
DROP TABLE IF EXISTS users                CASCADE;

-- ── Lookup / Reference Tables ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS account_type (
  account_type_id SERIAL PRIMARY KEY,
  account_desc    VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS affiliation (
  affiliation_id   SERIAL PRIMARY KEY,
  affiliation_name VARCHAR(255) NOT NULL UNIQUE
);

-- gender_id was VARCHAR in the previous schema (no referential integrity).
-- Extracted to a proper lookup table to remove the partial/uncontrolled domain.
CREATE TABLE IF NOT EXISTS gender (
  gender_id   SERIAL PRIMARY KEY,
  gender_name VARCHAR(50) NOT NULL UNIQUE
);

-- ── Geography ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS province (
  province_id   SERIAL PRIMARY KEY,
  province_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS municipality (
  municipality_id   SERIAL PRIMARY KEY,
  province_id       INTEGER NOT NULL REFERENCES province(province_id) ON DELETE RESTRICT,
  municipality_name VARCHAR(255) NOT NULL,
  coordinates       VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS mountain (
  mountain_id     SERIAL PRIMARY KEY,
  municipality_id INTEGER NOT NULL REFERENCES municipality(municipality_id) ON DELETE RESTRICT,
  mountain_name   VARCHAR(255) NOT NULL,
  coordinates     VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS location (
  location_id SERIAL PRIMARY KEY,
  mountain_id INTEGER NOT NULL REFERENCES mountain(mountain_id) ON DELETE RESTRICT
);

-- street_detail replaces the old city_name column; the province/municipality
-- are already reachable via the FK chain, so only the sub-municipal detail
-- belongs here.
CREATE TABLE IF NOT EXISTS address (
  address_id      SERIAL PRIMARY KEY,
  municipality_id INTEGER REFERENCES municipality(municipality_id) ON DELETE SET NULL,
  street_detail   VARCHAR(255)
);

-- ── User & Account ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS "user" (
  user_id        SERIAL PRIMARY KEY,
  first_name     VARCHAR(255) NOT NULL,
  last_name      VARCHAR(255) NOT NULL,
  -- gender_id is now a proper FK (was VARCHAR in previous schema).
  gender_id      INTEGER REFERENCES gender(gender_id) ON DELETE SET NULL,
  address_id     INTEGER REFERENCES address(address_id) ON DELETE SET NULL,
  affiliation_id INTEGER REFERENCES affiliation(affiliation_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS account (
  account_id      SERIAL PRIMARY KEY,
  user_id         INTEGER NOT NULL REFERENCES "user"(user_id) ON DELETE CASCADE,
  email           VARCHAR(255) NOT NULL UNIQUE,
  username        VARCHAR(255) UNIQUE,
  password        VARCHAR(255) NOT NULL,
  account_type_id INTEGER REFERENCES account_type(account_type_id) ON DELETE SET NULL,
  creation_date   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Orchid Taxonomy ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS genus (
  genus_id   SERIAL PRIMARY KEY,
  genus_name VARCHAR(255) NOT NULL UNIQUE
);

-- status_desc removed: it was transitively dependent on status_name
-- (conservation_id → status_name → status_desc).  The description is
-- implied by the IUCN category name itself; threats vary per record
-- so they remain a direct attribute of this table.
CREATE TABLE IF NOT EXISTS conservation_status (
  conservation_id SERIAL PRIMARY KEY,
  status_name     VARCHAR(255) NOT NULL UNIQUE,
  threats         VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS morphological_characteristics (
  morphological_id SERIAL PRIMARY KEY,
  leaf_type        VARCHAR(255),
  flower_color     VARCHAR(255),
  flowering_season VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS specie_value (
  specie_val_id      SERIAL PRIMARY KEY,
  ethnobotanical     VARCHAR(255),
  horticulture_value VARCHAR(255),
  cultural_imp       VARCHAR(255)
);

-- ── Media ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS picture (
  picture_id    SERIAL PRIMARY KEY,
  file_name     VARCHAR(255),
  file_path     VARCHAR(255) NOT NULL UNIQUE,
  file_type     VARCHAR(100),
  file_size     INTEGER,
  date_uploaded TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Habitat ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS habitat_information (
  habitat_id            SERIAL PRIMARY KEY,
  location_id           INTEGER REFERENCES location(location_id) ON DELETE SET NULL,
  elevation             VARCHAR(255),
  altitude              VARCHAR(255),
  vertical_distribution VARCHAR(255),
  habitat_type          VARCHAR(255),
  micro_habitat         VARCHAR(255)
);

-- ── Orchid Catalog ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS orchids (
  orchid_id       SERIAL PRIMARY KEY,
  sci_name        VARCHAR(255) NOT NULL UNIQUE,
  genus_id        INTEGER NOT NULL REFERENCES genus(genus_id) ON DELETE RESTRICT,
  common_name     VARCHAR(255),
  endemicity      VARCHAR(255),
  date_discovered TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS biogeography (
  biogeographic_id SERIAL PRIMARY KEY,
  orchid_id        INTEGER UNIQUE REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  habitat_id       INTEGER REFERENCES habitat_information(habitat_id) ON DELETE SET NULL,
  conservation_id  INTEGER REFERENCES conservation_status(conservation_id) ON DELETE SET NULL,
  picture_id       INTEGER REFERENCES picture(picture_id) ON DELETE SET NULL,
  user_id          INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL,
  morphological_id INTEGER REFERENCES morphological_characteristics(morphological_id) ON DELETE SET NULL,
  specie_val_id    INTEGER REFERENCES specie_value(specie_val_id) ON DELETE SET NULL,
  submission_status VARCHAR(30) NOT NULL DEFAULT 'pending'
    CHECK (lower(submission_status) IN ('approved', 'rejected', 'revision', 'pending'))
);

-- ── Legacy Users (kept for login/register code compatibility) ─────────────

CREATE TABLE IF NOT EXISTS users (
  id            SERIAL PRIMARY KEY,
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  email         VARCHAR(255) UNIQUE NOT NULL,
  birth_date    DATE,
  phone         VARCHAR(30),
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Field Sightings — Normalised Sub-Tables ───────────────────────────────
-- These tables hold the aspects of a sighting that previously caused the
-- species_sightings table to be very wide and contained transitive
-- dependencies.  Each one depends only on its own PK.

-- Habitat conditions observed at the time of sighting.
CREATE TABLE IF NOT EXISTS sighting_habitat (
  sighting_habitat_id  SERIAL PRIMARY KEY,
  habitat_type         VARCHAR(100),
  microhabitat         VARCHAR(100),
  growth_substrate     VARCHAR(100),
  host_tree_species    VARCHAR(255),
  host_tree_dbh_cm     NUMERIC(8, 2),
  canopy_cover_percent NUMERIC(5, 2),
  light_exposure       VARCHAR(50),
  soil_type            VARCHAR(100),
  nearby_water_source  VARCHAR(100)
);

-- Morphological measurements recorded during the sighting.
CREATE TABLE IF NOT EXISTS sighting_morphology (
  sighting_morphology_id   SERIAL PRIMARY KEY,
  plant_height_cm          NUMERIC(8, 2),
  pseudobulb_present       BOOLEAN,
  stem_length_cm           NUMERIC(8, 2),
  root_length_cm           NUMERIC(8, 2),
  leaf_count               INTEGER,
  leaf_shape               VARCHAR(120),
  leaf_shape_other         VARCHAR(255),
  leaf_length_cm           NUMERIC(8, 2),
  leaf_width_cm            NUMERIC(8, 2),
  leaf_textures            JSONB NOT NULL DEFAULT '[]'::jsonb,
  leaf_arrangement         VARCHAR(50),
  flower_color             VARCHAR(120),
  flower_count             INTEGER,
  flower_diameter_cm       NUMERIC(8, 2),
  inflorescence_type       VARCHAR(50),
  petal_characteristics    VARCHAR(50),
  sepal_characteristics    VARCHAR(255),
  labellum_lip_description VARCHAR(80),
  fragrance                VARCHAR(50),
  blooming_stage           VARCHAR(60),
  flowering_season         VARCHAR(60),
  fruit_present            BOOLEAN,
  fruit_type               VARCHAR(50),
  seed_capsule_condition   VARCHAR(80),
  life_stage               VARCHAR(50),
  phenology                VARCHAR(50),
  population_count         INTEGER
);

-- Conservation / threat data recorded during the sighting.
CREATE TABLE IF NOT EXISTS sighting_conservation (
  sighting_conservation_id SERIAL PRIMARY KEY,
  population_status        VARCHAR(50),
  threat_level             VARCHAR(50),
  threat_types             JSONB NOT NULL DEFAULT '[]'::jsonb
);

-- ── Field Sightings — Core Table ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS species_sightings (
  sighting_id              SERIAL PRIMARY KEY,
  entry_id                 VARCHAR(64) NOT NULL UNIQUE,

  -- Researcher identity.
  -- researcher_name removed: transitively dependent on researcher_email /
  -- user_id (sighting_id → researcher_email → researcher_name).
  -- Name is retrieved by joining account/user on researcher_email or user_id.
  -- institution removed: transitively dependent on user_id
  -- (sighting_id → user_id → affiliation_id → affiliation_name).
  user_id                  INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL,
  researcher_email         VARCHAR(255),

  -- Species identification.
  scientific_name          VARCHAR(255) NOT NULL,
  common_names             JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- common_name (scalar) removed: it was derived from common_names[0],
  -- a transitive / redundant dependency.
  -- genus removed: transitively derived from scientific_name
  -- (genus = first token of the binomial name).
  identification_confidence VARCHAR(30) NOT NULL DEFAULT 'Unidentified',
  endemic_to_philippines   VARCHAR(10),
  local_names              JSONB NOT NULL DEFAULT '[]'::jsonb,

  -- Observation event.
  observation_date         DATE,
  observation_time         TIME,
  collection_method        VARCHAR(50),
  observation_type         VARCHAR(50),
  voucher_collected        BOOLEAN,

  -- Location.
  -- mountain_name replaced by mountain_id FK so mountain attributes are not
  -- duplicated across rows (sighting_id → mountain_name → mountain.coordinates
  -- was a transitive dependency).
  mountain_id              INTEGER REFERENCES mountain(mountain_id) ON DELETE SET NULL,
  specific_site_zone       VARCHAR(120),
  specific_site_other      VARCHAR(255),
  latitude                 DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude                DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  elevation_meters         NUMERIC(8, 2),

  -- Normalised observation detail (FK to sub-tables above).
  sighting_habitat_id      INTEGER REFERENCES sighting_habitat(sighting_habitat_id) ON DELETE SET NULL,
  sighting_morphology_id   INTEGER REFERENCES sighting_morphology(sighting_morphology_id) ON DELETE SET NULL,
  sighting_conservation_id INTEGER REFERENCES sighting_conservation(sighting_conservation_id) ON DELETE SET NULL,

  -- Additional metadata.
  related_study            TEXT,
  researcher_notes         TEXT,

  review_status            VARCHAR(30) NOT NULL DEFAULT 'pending'
    CHECK (lower(review_status) IN ('approved', 'rejected', 'revision', 'pending', 'draft')),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Team members for a sighting.
-- Replaces team_members TEXT which violated 1NF by storing multiple
-- names/roles as a single concatenated string.
CREATE TABLE IF NOT EXISTS sighting_team_member (
  team_member_id SERIAL PRIMARY KEY,
  sighting_id    INTEGER NOT NULL REFERENCES species_sightings(sighting_id) ON DELETE CASCADE,
  member_name    VARCHAR(255) NOT NULL,
  member_role    VARCHAR(100),
  user_id        INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL
);

-- Media files attached to a sighting.
-- Replaces the nine denormalised columns
-- (whole_plant_photo_path, closeup_flower_photo_path, habitat_photo_path,
--  photo_3d_path, video_path, whole_plant_photographer,
--  closeup_flower_photographer, habitat_photographer, photo_3d_photographer)
-- which stored repeating groups across multiple columns.
CREATE TABLE IF NOT EXISTS sighting_media (
  sighting_media_id SERIAL PRIMARY KEY,
  sighting_id       INTEGER NOT NULL REFERENCES species_sightings(sighting_id) ON DELETE CASCADE,
  picture_id        INTEGER NOT NULL REFERENCES picture(picture_id) ON DELETE CASCADE,
  media_category    VARCHAR(50) NOT NULL
    CHECK (media_category IN ('whole_plant', 'closeup_flower', 'habitat', 'photo_3d', 'video')),
  photographer_name VARCHAR(255),
  sort_order        SMALLINT NOT NULL DEFAULT 0
);

-- ── Indexes ───────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_orchids_genus_id
  ON orchids(genus_id);
CREATE INDEX IF NOT EXISTS idx_biogeography_orchid_id
  ON biogeography(orchid_id);
CREATE INDEX IF NOT EXISTS idx_account_user_id
  ON account(user_id);
CREATE INDEX IF NOT EXISTS idx_municipality_province_id
  ON municipality(province_id);
CREATE INDEX IF NOT EXISTS idx_mountain_municipality_id
  ON mountain(municipality_id);
CREATE INDEX IF NOT EXISTS idx_species_sightings_created_at
  ON species_sightings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_species_sightings_user_id
  ON species_sightings(user_id);
CREATE INDEX IF NOT EXISTS idx_species_sightings_review_status
  ON species_sightings(review_status);
CREATE INDEX IF NOT EXISTS idx_species_sightings_mountain_id
  ON species_sightings(mountain_id);
CREATE INDEX IF NOT EXISTS idx_sighting_team_member_sighting_id
  ON sighting_team_member(sighting_id);
CREATE INDEX IF NOT EXISTS idx_sighting_media_sighting_id
  ON sighting_media(sighting_id);

-- ── Seed Lookup Data ──────────────────────────────────────────────────────

INSERT INTO account_type (account_desc)
VALUES ('admin'), ('researcher'), ('user')
ON CONFLICT (account_desc) DO NOTHING;

INSERT INTO gender (gender_name)
VALUES ('Male'), ('Female'), ('Non-binary'), ('Prefer not to say')
ON CONFLICT (gender_name) DO NOTHING;

COMMIT;
