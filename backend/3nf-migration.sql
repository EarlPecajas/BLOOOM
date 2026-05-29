-- ============================================================
-- 3NF Migration: apply normalisation changes to the live DB.
-- Run each section carefully; back up the database first.
-- ============================================================

BEGIN;

-- ── 1. gender lookup table (fixes "user".gender_id VARCHAR) ──────────────

CREATE TABLE IF NOT EXISTS gender (
  gender_id   SERIAL PRIMARY KEY,
  gender_name VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO gender (gender_name)
VALUES ('Male'), ('Female'), ('Non-binary'), ('Prefer not to say')
ON CONFLICT (gender_name) DO NOTHING;

-- Convert the existing free-text gender_id values to FK references.
-- Any unrecognised value is mapped to NULL.
ALTER TABLE "user"
  ADD COLUMN IF NOT EXISTS gender_fk INTEGER REFERENCES gender(gender_id) ON DELETE SET NULL;

UPDATE "user" u
SET gender_fk = g.gender_id
FROM gender g
WHERE lower(trim(u.gender_id)) = lower(g.gender_name);

ALTER TABLE "user" DROP COLUMN IF EXISTS gender_id;
ALTER TABLE "user" RENAME COLUMN gender_fk TO gender_id;

-- ── 2. conservation_status — remove status_desc (transitive dependency) ──

ALTER TABLE conservation_status
  ADD COLUMN IF NOT EXISTS status_name VARCHAR(255);

UPDATE conservation_status
SET status_name = conservation_status
WHERE status_name IS NULL;

ALTER TABLE conservation_status
  ALTER COLUMN status_name SET NOT NULL;

ALTER TABLE conservation_status
  DROP COLUMN IF EXISTS status_desc;

-- Add unique constraint on status_name (it is the natural candidate key).
ALTER TABLE conservation_status
  DROP CONSTRAINT IF EXISTS conservation_status_status_name_key;
ALTER TABLE conservation_status
  ADD CONSTRAINT conservation_status_status_name_key UNIQUE (status_name);

-- ── 3. sighting_habitat sub-table ────────────────────────────────────────

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

INSERT INTO sighting_habitat (
  habitat_type, microhabitat, growth_substrate, host_tree_species,
  host_tree_dbh_cm, canopy_cover_percent, light_exposure, soil_type,
  nearby_water_source
)
SELECT
  habitat_type, microhabitat, growth_substrate, host_tree_species,
  host_tree_dbh_cm, canopy_cover_percent, light_exposure, soil_type,
  nearby_water_source
FROM species_sightings;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS sighting_habitat_id INTEGER
    REFERENCES sighting_habitat(sighting_habitat_id) ON DELETE SET NULL;

UPDATE species_sightings ss
SET sighting_habitat_id = sh.sighting_habitat_id
FROM sighting_habitat sh
WHERE ss.sighting_id = (
  SELECT s2.sighting_id FROM species_sightings s2
  WHERE s2.habitat_type IS NOT DISTINCT FROM sh.habitat_type
    AND s2.microhabitat IS NOT DISTINCT FROM sh.microhabitat
    AND s2.growth_substrate IS NOT DISTINCT FROM sh.growth_substrate
    AND s2.host_tree_species IS NOT DISTINCT FROM sh.host_tree_species
  LIMIT 1
);

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS habitat_type,
  DROP COLUMN IF EXISTS microhabitat,
  DROP COLUMN IF EXISTS growth_substrate,
  DROP COLUMN IF EXISTS host_tree_species,
  DROP COLUMN IF EXISTS host_tree_dbh_cm,
  DROP COLUMN IF EXISTS canopy_cover_percent,
  DROP COLUMN IF EXISTS light_exposure,
  DROP COLUMN IF EXISTS soil_type,
  DROP COLUMN IF EXISTS nearby_water_source;

-- ── 4. sighting_morphology sub-table ─────────────────────────────────────

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

INSERT INTO sighting_morphology (
  plant_height_cm, pseudobulb_present, stem_length_cm, root_length_cm,
  leaf_count, leaf_shape, leaf_shape_other, leaf_length_cm, leaf_width_cm,
  leaf_textures, leaf_arrangement, flower_color, flower_count,
  flower_diameter_cm, inflorescence_type, petal_characteristics,
  sepal_characteristics, labellum_lip_description, fragrance, blooming_stage,
  flowering_season, fruit_present, fruit_type, seed_capsule_condition,
  life_stage, phenology, population_count
)
SELECT
  plant_height_cm, pseudobulb_present, stem_length_cm, root_length_cm,
  leaf_count, leaf_shape, leaf_shape_other, leaf_length_cm, leaf_width_cm,
  leaf_textures, leaf_arrangement, flower_color, flower_count,
  flower_diameter_cm, inflorescence_type, petal_characteristics,
  sepal_characteristics, labellum_lip_description, fragrance, blooming_stage,
  flowering_season, fruit_present, fruit_type, seed_capsule_condition,
  life_stage, phenology, population_count
FROM species_sightings;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS sighting_morphology_id INTEGER
    REFERENCES sighting_morphology(sighting_morphology_id) ON DELETE SET NULL;

-- Link each sighting to its morphology row by sighting_id row order.
WITH ranked AS (
  SELECT sighting_id, ROW_NUMBER() OVER (ORDER BY sighting_id) AS rn
  FROM species_sightings
),
morph_ranked AS (
  SELECT sighting_morphology_id, ROW_NUMBER() OVER (ORDER BY sighting_morphology_id) AS rn
  FROM sighting_morphology
)
UPDATE species_sightings ss
SET sighting_morphology_id = mr.sighting_morphology_id
FROM ranked r
JOIN morph_ranked mr ON r.rn = mr.rn
WHERE ss.sighting_id = r.sighting_id;

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS plant_height_cm,
  DROP COLUMN IF EXISTS pseudobulb_present,
  DROP COLUMN IF EXISTS stem_length_cm,
  DROP COLUMN IF EXISTS root_length_cm,
  DROP COLUMN IF EXISTS leaf_count,
  DROP COLUMN IF EXISTS leaf_shape,
  DROP COLUMN IF EXISTS leaf_shape_other,
  DROP COLUMN IF EXISTS leaf_length_cm,
  DROP COLUMN IF EXISTS leaf_width_cm,
  DROP COLUMN IF EXISTS leaf_textures,
  DROP COLUMN IF EXISTS leaf_arrangement,
  DROP COLUMN IF EXISTS flower_color,
  DROP COLUMN IF EXISTS flower_count,
  DROP COLUMN IF EXISTS flower_diameter_cm,
  DROP COLUMN IF EXISTS inflorescence_type,
  DROP COLUMN IF EXISTS petal_characteristics,
  DROP COLUMN IF EXISTS sepal_characteristics,
  DROP COLUMN IF EXISTS labellum_lip_description,
  DROP COLUMN IF EXISTS fragrance,
  DROP COLUMN IF EXISTS blooming_stage,
  DROP COLUMN IF EXISTS flowering_season,
  DROP COLUMN IF EXISTS fruit_present,
  DROP COLUMN IF EXISTS fruit_type,
  DROP COLUMN IF EXISTS seed_capsule_condition,
  DROP COLUMN IF EXISTS life_stage,
  DROP COLUMN IF EXISTS phenology,
  DROP COLUMN IF EXISTS population_count;

-- ── 5. sighting_conservation sub-table ───────────────────────────────────

CREATE TABLE IF NOT EXISTS sighting_conservation (
  sighting_conservation_id SERIAL PRIMARY KEY,
  population_status        VARCHAR(50),
  threat_level             VARCHAR(50),
  threat_types             JSONB NOT NULL DEFAULT '[]'::jsonb
);

INSERT INTO sighting_conservation (population_status, threat_level, threat_types)
SELECT population_status, threat_level, COALESCE(threat_types, '[]'::jsonb)
FROM species_sightings;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS sighting_conservation_id INTEGER
    REFERENCES sighting_conservation(sighting_conservation_id) ON DELETE SET NULL;

WITH ranked AS (
  SELECT sighting_id, ROW_NUMBER() OVER (ORDER BY sighting_id) AS rn
  FROM species_sightings
),
cons_ranked AS (
  SELECT sighting_conservation_id, ROW_NUMBER() OVER (ORDER BY sighting_conservation_id) AS rn
  FROM sighting_conservation
)
UPDATE species_sightings ss
SET sighting_conservation_id = cr.sighting_conservation_id
FROM ranked r
JOIN cons_ranked cr ON r.rn = cr.rn
WHERE ss.sighting_id = r.sighting_id;

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS population_status,
  DROP COLUMN IF EXISTS threat_level,
  DROP COLUMN IF EXISTS threat_types;

-- ── 6. sighting_team_member table (fixes 1NF: team_members TEXT) ─────────

CREATE TABLE IF NOT EXISTS sighting_team_member (
  team_member_id SERIAL PRIMARY KEY,
  sighting_id    INTEGER NOT NULL REFERENCES species_sightings(sighting_id) ON DELETE CASCADE,
  member_name    VARCHAR(255) NOT NULL,
  member_role    VARCHAR(100),
  user_id        INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL
);

-- Migrate existing comma-separated team_members TEXT to individual rows.
INSERT INTO sighting_team_member (sighting_id, member_name)
SELECT
  sighting_id,
  trim(member) AS member_name
FROM species_sightings,
     unnest(string_to_array(team_members, ',')) AS member
WHERE team_members IS NOT NULL AND trim(team_members) <> '';

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS team_members;

-- ── 7. sighting_media table (fixes repeating photo-path/photographer cols) ─

CREATE TABLE IF NOT EXISTS sighting_media (
  sighting_media_id SERIAL PRIMARY KEY,
  sighting_id       INTEGER NOT NULL REFERENCES species_sightings(sighting_id) ON DELETE CASCADE,
  picture_id        INTEGER NOT NULL REFERENCES picture(picture_id) ON DELETE CASCADE,
  media_category    VARCHAR(50) NOT NULL
    CHECK (media_category IN ('whole_plant', 'closeup_flower', 'habitat', 'photo_3d', 'video')),
  photographer_name VARCHAR(255),
  sort_order        SMALLINT NOT NULL DEFAULT 0
);

-- NOTE: Existing JSONB path arrays in whole_plant_photo_path etc. reference
-- Supabase Storage URLs, not rows in the picture table.  Insert the URLs
-- as picture rows first, then link via sighting_media.

INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(whole_plant_photo_path) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT
  ss.sighting_id,
  p.picture_id,
  'whole_plant',
  elem->>'contributor',
  (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(ss.whole_plant_photo_path) WITH ORDINALITY AS t(elem, ordinality)
JOIN picture p ON p.file_path = elem->>'src'
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> '';

INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(closeup_flower_photo_path) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT
  ss.sighting_id,
  p.picture_id,
  'closeup_flower',
  elem->>'contributor',
  (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(ss.closeup_flower_photo_path) WITH ORDINALITY AS t(elem, ordinality)
JOIN picture p ON p.file_path = elem->>'src'
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> '';

INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(habitat_photo_path) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT
  ss.sighting_id,
  p.picture_id,
  'habitat',
  elem->>'contributor',
  (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(ss.habitat_photo_path) WITH ORDINALITY AS t(elem, ordinality)
JOIN picture p ON p.file_path = elem->>'src'
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> '';

INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(video_path) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT
  ss.sighting_id,
  p.picture_id,
  'video',
  NULL,
  (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(ss.video_path) WITH ORDINALITY AS t(elem, ordinality)
JOIN picture p ON p.file_path = elem->>'src'
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> '';

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS whole_plant_photo_path,
  DROP COLUMN IF EXISTS closeup_flower_photo_path,
  DROP COLUMN IF EXISTS habitat_photo_path,
  DROP COLUMN IF EXISTS photo_3d_path,
  DROP COLUMN IF EXISTS video_path,
  DROP COLUMN IF EXISTS whole_plant_photographer,
  DROP COLUMN IF EXISTS closeup_flower_photographer,
  DROP COLUMN IF EXISTS habitat_photographer,
  DROP COLUMN IF EXISTS photo_3d_photographer;

-- ── 8. Remove transitive columns from species_sightings ──────────────────

-- researcher_name: sighting_id → researcher_email → researcher_name
-- (name is available via JOIN on account.email or "user".user_id)
ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS researcher_name;

-- institution: sighting_id → user_id → affiliation_id → affiliation_name
-- (institution is stored in "user".affiliation_id)
ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS institution;

-- genus: sighting_id → scientific_name → genus
-- (genus = split_part(scientific_name, ' ', 1))
ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS genus;

-- common_name (scalar): derived from common_names[0]
-- Use common_names JSONB as the single source of truth.
ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS common_name;

-- ── 9. Replace mountain_name with mountain_id FK ─────────────────────────

-- First ensure Mt. Busa exists in mountain table.
INSERT INTO province (province_name) VALUES ('Sarangani') ON CONFLICT DO NOTHING;
INSERT INTO municipality (province_id, municipality_name)
  SELECT province_id, 'Kiamba' FROM province WHERE province_name = 'Sarangani'
  ON CONFLICT DO NOTHING;
INSERT INTO mountain (municipality_id, mountain_name, coordinates)
  SELECT municipality_id, 'Mt. Busa', '6.1064,124.6699'
  FROM municipality WHERE municipality_name = 'Kiamba'
  ON CONFLICT DO NOTHING;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS mountain_id INTEGER
    REFERENCES mountain(mountain_id) ON DELETE SET NULL;

UPDATE species_sightings ss
SET mountain_id = m.mountain_id
FROM mountain m
WHERE lower(trim(ss.mountain_name)) = lower(trim(m.mountain_name));

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS mountain_name;

-- ── 10. New indexes ───────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_species_sightings_mountain_id
  ON species_sightings(mountain_id);
CREATE INDEX IF NOT EXISTS idx_sighting_team_member_sighting_id
  ON sighting_team_member(sighting_id);
CREATE INDEX IF NOT EXISTS idx_sighting_media_sighting_id
  ON sighting_media(sighting_id);
CREATE INDEX IF NOT EXISTS idx_sighting_media_category
  ON sighting_media(media_category);

COMMIT;
