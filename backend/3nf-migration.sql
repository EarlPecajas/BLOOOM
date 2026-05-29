-- ============================================================
-- 3NF Migration: apply normalisation changes to the live DB.
-- Run each section carefully; back up the database first.
-- ============================================================

BEGIN;

-- ── 0. Drop dependent views FIRST ────────────────────────────────────────
-- Views reference columns that are being moved; they are recreated at the
-- end of this script using JOINs to the new sub-tables.

DROP VIEW IF EXISTS public_approved_sightings;
DROP VIEW IF EXISTS denr_approved_sightings;

-- ── 1. gender lookup table (fixes "user".gender_id VARCHAR) ──────────────

CREATE TABLE IF NOT EXISTS gender (
  gender_id   SERIAL PRIMARY KEY,
  gender_name VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO gender (gender_name)
VALUES ('Male'), ('Female'), ('Non-binary'), ('Prefer not to say')
ON CONFLICT (gender_name) DO NOTHING;

ALTER TABLE "user"
  ADD COLUMN IF NOT EXISTS gender_fk INTEGER
    REFERENCES gender(gender_id) ON DELETE SET NULL;

UPDATE "user" u
SET gender_fk = g.gender_id
FROM gender g
WHERE lower(trim(u.gender_id::text)) = lower(g.gender_name);

ALTER TABLE "user" DROP COLUMN IF EXISTS gender_id;
ALTER TABLE "user" RENAME COLUMN gender_fk TO gender_id;

-- ── 1b. affiliation — rename column to match 3NF schema ──────────────────
-- Live DB has column 'affiliation'; 3NF schema uses 'affiliation_name'.
ALTER TABLE affiliation
  RENAME COLUMN affiliation TO affiliation_name;

-- ── 2. conservation_status — remove status_desc (transitive dependency) ──
-- status_desc was transitively determined by the conservation_status value
-- column: conservation_id → conservation_status → status_desc.

ALTER TABLE conservation_status
  ADD COLUMN IF NOT EXISTS status_name VARCHAR(255);

UPDATE conservation_status
SET status_name = conservation_status
WHERE status_name IS NULL;

ALTER TABLE conservation_status
  ALTER COLUMN status_name SET NOT NULL;

ALTER TABLE conservation_status
  DROP COLUMN IF EXISTS status_desc;

ALTER TABLE conservation_status
  DROP CONSTRAINT IF EXISTS conservation_status_status_name_key;
ALTER TABLE conservation_status
  ADD CONSTRAINT conservation_status_status_name_key UNIQUE (status_name);

-- ── 3. sighting_habitat sub-table ────────────────────────────────────────
-- A _sighting_id temp column is used so each sub-table row can be linked
-- back to exactly the sighting it came from before being dropped.

CREATE TABLE IF NOT EXISTS sighting_habitat (
  sighting_habitat_id  SERIAL PRIMARY KEY,
  _sighting_id         INTEGER,           -- temp; dropped at the end of this block
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
  _sighting_id,
  habitat_type, microhabitat, growth_substrate, host_tree_species,
  host_tree_dbh_cm, canopy_cover_percent, light_exposure, soil_type,
  nearby_water_source
)
SELECT
  sighting_id,
  habitat_type, microhabitat, growth_substrate, host_tree_species,
  host_tree_dbh_cm, canopy_cover_percent, light_exposure, soil_type,
  nearby_water_source
FROM species_sightings;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS sighting_habitat_id INTEGER;

UPDATE species_sightings ss
SET sighting_habitat_id = sh.sighting_habitat_id
FROM sighting_habitat sh
WHERE sh._sighting_id = ss.sighting_id;

ALTER TABLE sighting_habitat DROP COLUMN _sighting_id;

ALTER TABLE sighting_habitat
  ADD CONSTRAINT fk_sighting_habitat_sighting_id_check CHECK (true); -- placeholder keeps DDL clean

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

ALTER TABLE species_sightings
  ADD CONSTRAINT fk_ss_habitat
    FOREIGN KEY (sighting_habitat_id)
    REFERENCES sighting_habitat(sighting_habitat_id)
    ON DELETE SET NULL;

-- ── 4. sighting_morphology sub-table ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS sighting_morphology (
  sighting_morphology_id   SERIAL PRIMARY KEY,
  _sighting_id             INTEGER,
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
  _sighting_id,
  plant_height_cm, pseudobulb_present, stem_length_cm, root_length_cm,
  leaf_count, leaf_shape, leaf_shape_other, leaf_length_cm, leaf_width_cm,
  leaf_textures, leaf_arrangement, flower_color, flower_count,
  flower_diameter_cm, inflorescence_type, petal_characteristics,
  sepal_characteristics, labellum_lip_description, fragrance, blooming_stage,
  flowering_season, fruit_present, fruit_type, seed_capsule_condition,
  life_stage, phenology, population_count
)
SELECT
  sighting_id,
  plant_height_cm, pseudobulb_present, stem_length_cm, root_length_cm,
  leaf_count, leaf_shape, leaf_shape_other, leaf_length_cm, leaf_width_cm,
  leaf_textures, leaf_arrangement, flower_color, flower_count,
  flower_diameter_cm, inflorescence_type, petal_characteristics,
  sepal_characteristics, labellum_lip_description, fragrance, blooming_stage,
  flowering_season, fruit_present, fruit_type, seed_capsule_condition,
  life_stage, phenology, population_count
FROM species_sightings;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS sighting_morphology_id INTEGER;

UPDATE species_sightings ss
SET sighting_morphology_id = sm.sighting_morphology_id
FROM sighting_morphology sm
WHERE sm._sighting_id = ss.sighting_id;

ALTER TABLE sighting_morphology DROP COLUMN _sighting_id;

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

ALTER TABLE species_sightings
  ADD CONSTRAINT fk_ss_morphology
    FOREIGN KEY (sighting_morphology_id)
    REFERENCES sighting_morphology(sighting_morphology_id)
    ON DELETE SET NULL;

-- ── 5. sighting_conservation sub-table ───────────────────────────────────

CREATE TABLE IF NOT EXISTS sighting_conservation (
  sighting_conservation_id SERIAL PRIMARY KEY,
  _sighting_id             INTEGER,
  population_status        VARCHAR(50),
  threat_level             VARCHAR(50),
  threat_types             JSONB NOT NULL DEFAULT '[]'::jsonb
);

INSERT INTO sighting_conservation (_sighting_id, population_status, threat_level, threat_types)
SELECT sighting_id, population_status, threat_level, COALESCE(threat_types, '[]'::jsonb)
FROM species_sightings;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS sighting_conservation_id INTEGER;

UPDATE species_sightings ss
SET sighting_conservation_id = sc.sighting_conservation_id
FROM sighting_conservation sc
WHERE sc._sighting_id = ss.sighting_id;

ALTER TABLE sighting_conservation DROP COLUMN _sighting_id;

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS population_status,
  DROP COLUMN IF EXISTS threat_level,
  DROP COLUMN IF EXISTS threat_types;

ALTER TABLE species_sightings
  ADD CONSTRAINT fk_ss_conservation
    FOREIGN KEY (sighting_conservation_id)
    REFERENCES sighting_conservation(sighting_conservation_id)
    ON DELETE SET NULL;

-- ── 6. sighting_team_member (fixes 1NF: team_members TEXT) ───────────────

CREATE TABLE IF NOT EXISTS sighting_team_member (
  team_member_id SERIAL PRIMARY KEY,
  sighting_id    INTEGER NOT NULL
    REFERENCES species_sightings(sighting_id) ON DELETE CASCADE,
  member_name    VARCHAR(255) NOT NULL,
  member_role    VARCHAR(100),
  user_id        INTEGER REFERENCES "user"(user_id) ON DELETE SET NULL
);

INSERT INTO sighting_team_member (sighting_id, member_name)
SELECT
  sighting_id,
  trim(member) AS member_name
FROM species_sightings,
     unnest(string_to_array(team_members, ',')) AS member
WHERE team_members IS NOT NULL AND trim(team_members) <> '';

ALTER TABLE species_sightings
  DROP COLUMN IF EXISTS team_members;

-- ── 7. sighting_media (fixes repeating photo-path / photographer columns) ─

CREATE TABLE IF NOT EXISTS sighting_media (
  sighting_media_id SERIAL PRIMARY KEY,
  sighting_id       INTEGER NOT NULL
    REFERENCES species_sightings(sighting_id) ON DELETE CASCADE,
  picture_id        INTEGER NOT NULL
    REFERENCES picture(picture_id) ON DELETE CASCADE,
  media_category    VARCHAR(50) NOT NULL
    CHECK (media_category IN ('whole_plant', 'closeup_flower', 'habitat', 'photo_3d', 'video')),
  photographer_name VARCHAR(255),
  sort_order        SMALLINT NOT NULL DEFAULT 0
);

-- Register file paths in picture then link via sighting_media.
-- Columns may contain either a plain URL string ("https://...") or a
-- JSON array ("[{\"src\":\"...\"}]") depending on whether the earlier
-- migrate-alter-media-to-jsonb.sql was applied.
-- The helper expression normalises both forms into a jsonb array:
--   NULL / ''       → '[]' (zero rows from jsonb_array_elements)
--   starts with '[' → parse as jsonb array
--   plain URL       → wrap as [{"src": "<url>"}]

-- whole_plant
INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(whole_plant_photo_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(whole_plant_photo_path::text), 1) = '[' THEN trim(whole_plant_photo_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(whole_plant_photo_path::text)))
       END
     ) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT ss.sighting_id, p.picture_id, 'whole_plant', elem->>'contributor',
       (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(ss.whole_plant_photo_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(ss.whole_plant_photo_path::text), 1) = '[' THEN trim(ss.whole_plant_photo_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(ss.whole_plant_photo_path::text)))
       END
     ) WITH ORDINALITY AS t(elem, ordinality)
JOIN picture p ON p.file_path = elem->>'src'
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> '';

-- closeup_flower
INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(closeup_flower_photo_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(closeup_flower_photo_path::text), 1) = '[' THEN trim(closeup_flower_photo_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(closeup_flower_photo_path::text)))
       END
     ) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT ss.sighting_id, p.picture_id, 'closeup_flower', elem->>'contributor',
       (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(ss.closeup_flower_photo_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(ss.closeup_flower_photo_path::text), 1) = '[' THEN trim(ss.closeup_flower_photo_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(ss.closeup_flower_photo_path::text)))
       END
     ) WITH ORDINALITY AS t(elem, ordinality)
JOIN picture p ON p.file_path = elem->>'src'
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> '';

-- habitat
INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(habitat_photo_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(habitat_photo_path::text), 1) = '[' THEN trim(habitat_photo_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(habitat_photo_path::text)))
       END
     ) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT ss.sighting_id, p.picture_id, 'habitat', elem->>'contributor',
       (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(ss.habitat_photo_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(ss.habitat_photo_path::text), 1) = '[' THEN trim(ss.habitat_photo_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(ss.habitat_photo_path::text)))
       END
     ) WITH ORDINALITY AS t(elem, ordinality)
JOIN picture p ON p.file_path = elem->>'src'
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> '';

-- video
INSERT INTO picture (file_path)
SELECT DISTINCT elem->>'src'
FROM species_sightings,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(video_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(video_path::text), 1) = '[' THEN trim(video_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(video_path::text)))
       END
     ) AS elem
WHERE elem->>'src' IS NOT NULL AND trim(elem->>'src') <> ''
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO sighting_media (sighting_id, picture_id, media_category, photographer_name, sort_order)
SELECT ss.sighting_id, p.picture_id, 'video', NULL,
       (row_number() OVER (PARTITION BY ss.sighting_id ORDER BY ordinality))::smallint - 1
FROM species_sightings ss,
     jsonb_array_elements(
       CASE
         WHEN NULLIF(trim(ss.video_path::text), '') IS NULL THEN '[]'::jsonb
         WHEN left(trim(ss.video_path::text), 1) = '[' THEN trim(ss.video_path::text)::jsonb
         ELSE jsonb_build_array(jsonb_build_object('src', trim(ss.video_path::text)))
       END
     ) WITH ORDINALITY AS t(elem, ordinality)
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

-- ── 8. Remove transitive columns ─────────────────────────────────────────

-- researcher_name: sighting_id → researcher_email → researcher_name
ALTER TABLE species_sightings DROP COLUMN IF EXISTS researcher_name;

-- institution: sighting_id → user_id → affiliation_id → affiliation_name
ALTER TABLE species_sightings DROP COLUMN IF EXISTS institution;

-- genus: sighting_id → scientific_name → genus (first token of binomial)
ALTER TABLE species_sightings DROP COLUMN IF EXISTS genus;

-- common_name scalar: derived from common_names[0]
ALTER TABLE species_sightings DROP COLUMN IF EXISTS common_name;

-- ── 9. Replace mountain_name VARCHAR with mountain_id FK ─────────────────

INSERT INTO province (province_name)
  VALUES ('Sarangani')
  ON CONFLICT (province_name) DO NOTHING;

INSERT INTO municipality (province_id, municipality_name)
  SELECT province_id, 'Kiamba'
  FROM province WHERE province_name = 'Sarangani'
  ON CONFLICT DO NOTHING;

INSERT INTO mountain (municipality_id, mountain_name, coordinates)
  SELECT municipality_id, 'Mt. Busa', '6.1064,124.6699'
  FROM municipality WHERE municipality_name = 'Kiamba'
  ON CONFLICT DO NOTHING;

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS mountain_id INTEGER;

UPDATE species_sightings ss
SET mountain_id = m.mountain_id
FROM mountain m
WHERE lower(trim(ss.mountain_name)) = lower(trim(m.mountain_name));

ALTER TABLE species_sightings DROP COLUMN IF EXISTS mountain_name;

ALTER TABLE species_sightings
  ADD CONSTRAINT fk_ss_mountain
    FOREIGN KEY (mountain_id)
    REFERENCES mountain(mountain_id)
    ON DELETE SET NULL;

-- ── 10. New indexes ───────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_species_sightings_mountain_id
  ON species_sightings(mountain_id);
CREATE INDEX IF NOT EXISTS idx_sighting_team_member_sighting_id
  ON sighting_team_member(sighting_id);
CREATE INDEX IF NOT EXISTS idx_sighting_media_sighting_id
  ON sighting_media(sighting_id);
CREATE INDEX IF NOT EXISTS idx_sighting_media_category
  ON sighting_media(media_category);

-- ── 11. Recreate views using JOINs to the new sub-tables ─────────────────

CREATE OR REPLACE VIEW public_approved_sightings AS
SELECT
  s.sighting_id                                 AS id,
  s.scientific_name,
  s.common_names,
  s.local_names,
  s.identification_confidence,
  s.observation_date,
  to_char(s.observation_date, 'YYYY-MM')        AS observation_month,
  s.observation_time,
  s.observation_type,
  s.collection_method,
  s.voucher_collected,
  m.mountain_name,
  s.specific_site_zone,
  s.latitude,
  s.longitude,
  s.elevation_meters,
  sh.habitat_type,
  sh.microhabitat,
  sm.plant_height_cm,
  sm.leaf_shape,
  sm.leaf_count,
  sm.leaf_textures,
  sm.leaf_arrangement,
  sm.flower_color,
  sm.flower_count,
  sm.flower_diameter_cm,
  sm.inflorescence_type,
  sm.petal_characteristics,
  sm.labellum_lip_description,
  sm.fragrance,
  sm.flowering_season,
  sm.blooming_stage,
  sm.fruit_present,
  sm.fruit_type,
  sc.population_status,
  sc.threat_level,
  coalesce(sc.threat_level, '')                 AS threat_level_generalized,
  s.endemic_to_philippines,
  sh.growth_substrate,
  sh.nearby_water_source,
  s.researcher_notes,
  NULL::text                                    AS educational_notes,
  'Location hidden for conservation'::text      AS location_visibility_note,
  -- photo paths aggregated from sighting_media + picture
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', p.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture p ON p.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'whole_plant'
  )                                             AS whole_plant_photo_path,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', p.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture p ON p.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'closeup_flower'
  )                                             AS closeup_flower_photo_path,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', p.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture p ON p.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'habitat'
  )                                             AS habitat_photo_path,
  -- researcher name via user join
  (u.first_name || ' ' || u.last_name)          AS researcher_name,
  -- team members as comma-separated string for backward compatibility
  (SELECT string_agg(stm.member_name, ', ' ORDER BY stm.team_member_id)
   FROM sighting_team_member stm
   WHERE stm.sighting_id = s.sighting_id)       AS team_members,
  -- institution via affiliation lookup
  a.affiliation_name                            AS institution
FROM species_sightings s
LEFT JOIN mountain              m  ON m.mountain_id              = s.mountain_id
LEFT JOIN sighting_habitat      sh ON sh.sighting_habitat_id     = s.sighting_habitat_id
LEFT JOIN sighting_morphology   sm ON sm.sighting_morphology_id  = s.sighting_morphology_id
LEFT JOIN sighting_conservation sc ON sc.sighting_conservation_id = s.sighting_conservation_id
LEFT JOIN "user"                u  ON u.user_id                  = s.user_id
LEFT JOIN affiliation           a  ON a.affiliation_id           = u.affiliation_id
WHERE lower(coalesce(s.review_status, '')) = 'approved';

GRANT SELECT ON public_approved_sightings TO anon, authenticated;

-- denr_approved_sightings: same join set, no WHERE filter on review_status,
-- exposes all fields to authenticated (DENR) users.
CREATE OR REPLACE VIEW denr_approved_sightings AS
SELECT
  s.sighting_id,
  s.entry_id,
  s.user_id,
  s.researcher_email,
  s.scientific_name,
  s.common_names,
  s.local_names,
  s.identification_confidence,
  s.endemic_to_philippines,
  s.observation_date,
  s.observation_time,
  s.collection_method,
  s.observation_type,
  s.voucher_collected,
  m.mountain_name,
  s.mountain_id,
  s.specific_site_zone,
  s.specific_site_other,
  s.latitude,
  s.longitude,
  s.elevation_meters,
  sh.habitat_type,
  sh.microhabitat,
  sh.growth_substrate,
  sh.host_tree_species,
  sh.host_tree_dbh_cm,
  sh.canopy_cover_percent,
  sh.light_exposure,
  sh.soil_type,
  sh.nearby_water_source,
  sm.plant_height_cm,
  sm.pseudobulb_present,
  sm.stem_length_cm,
  sm.root_length_cm,
  sm.leaf_count,
  sm.leaf_shape,
  sm.leaf_shape_other,
  sm.leaf_length_cm,
  sm.leaf_width_cm,
  sm.leaf_textures,
  sm.leaf_arrangement,
  sm.flower_color,
  sm.flower_count,
  sm.flower_diameter_cm,
  sm.inflorescence_type,
  sm.petal_characteristics,
  sm.sepal_characteristics,
  sm.labellum_lip_description,
  sm.fragrance,
  sm.blooming_stage,
  sm.flowering_season,
  sm.fruit_present,
  sm.fruit_type,
  sm.seed_capsule_condition,
  sm.life_stage,
  sm.phenology,
  sm.population_count,
  sc.population_status,
  sc.threat_level,
  sc.threat_types,
  coalesce(sc.threat_level, '') AS threat_level_generalized,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', p.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture p ON p.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'whole_plant'
  ) AS whole_plant_photo_path,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', p.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture p ON p.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'closeup_flower'
  ) AS closeup_flower_photo_path,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', p.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture p ON p.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'habitat'
  ) AS habitat_photo_path,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', p.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture p ON p.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'video'
  ) AS video_path,
  (u.first_name || ' ' || u.last_name)     AS researcher_name,
  (SELECT string_agg(stm.member_name, ', ' ORDER BY stm.team_member_id)
   FROM sighting_team_member stm
   WHERE stm.sighting_id = s.sighting_id)  AS team_members,
  a.affiliation_name                       AS institution,
  s.related_study,
  s.researcher_notes,
  s.review_status,
  s.created_at,
  s.updated_at
FROM species_sightings s
LEFT JOIN mountain              m  ON m.mountain_id               = s.mountain_id
LEFT JOIN sighting_habitat      sh ON sh.sighting_habitat_id      = s.sighting_habitat_id
LEFT JOIN sighting_morphology   sm ON sm.sighting_morphology_id   = s.sighting_morphology_id
LEFT JOIN sighting_conservation sc ON sc.sighting_conservation_id = s.sighting_conservation_id
LEFT JOIN "user"                u  ON u.user_id                   = s.user_id
LEFT JOIN affiliation           a  ON a.affiliation_id            = u.affiliation_id
WHERE lower(coalesce(s.review_status, '')) = 'approved';

GRANT SELECT ON denr_approved_sightings TO authenticated;

COMMIT;
