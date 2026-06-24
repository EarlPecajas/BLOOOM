-- ============================================================
-- BLOOM3D Migration: Add all upload-form fields to species_sightings
-- Run once in Supabase SQL Editor (Dashboard > SQL Editor)
-- Safe to re-run: uses ADD COLUMN IF NOT EXISTS
-- ============================================================

ALTER TABLE species_sightings
  -- Taxonomy / identification
  ADD COLUMN IF NOT EXISTS local_names              TEXT,
  ADD COLUMN IF NOT EXISTS common_names             TEXT,
  ADD COLUMN IF NOT EXISTS endemic_to_philippines   BOOLEAN,
  ADD COLUMN IF NOT EXISTS identification_confidence TEXT,

  -- Location (non-coordinate)
  ADD COLUMN IF NOT EXISTS province                 TEXT,
  ADD COLUMN IF NOT EXISTS municipality             TEXT,
  ADD COLUMN IF NOT EXISTS specific_site            TEXT,

  -- Habitat / environment
  ADD COLUMN IF NOT EXISTS growth_substrate         TEXT,
  ADD COLUMN IF NOT EXISTS host_tree_species        TEXT,
  ADD COLUMN IF NOT EXISTS host_tree_diameter       TEXT,
  ADD COLUMN IF NOT EXISTS canopy_cover             TEXT,
  ADD COLUMN IF NOT EXISTS light_exposure           TEXT,
  ADD COLUMN IF NOT EXISTS soil_type                TEXT,
  ADD COLUMN IF NOT EXISTS nearby_water_source      TEXT,

  -- Plant structure
  ADD COLUMN IF NOT EXISTS plant_height             TEXT,
  ADD COLUMN IF NOT EXISTS pseudobulb_present       TEXT,
  ADD COLUMN IF NOT EXISTS stem_length              TEXT,
  ADD COLUMN IF NOT EXISTS root_length              TEXT,

  -- Leaf characteristics (leaf_shape already exists)
  ADD COLUMN IF NOT EXISTS leaf_length              TEXT,
  ADD COLUMN IF NOT EXISTS leaf_width               TEXT,
  ADD COLUMN IF NOT EXISTS leaf_texture             TEXT,
  ADD COLUMN IF NOT EXISTS leaf_arrangement         TEXT,
  ADD COLUMN IF NOT EXISTS number_of_leaves         TEXT,

  -- Flower characteristics (flower_color already exists)
  ADD COLUMN IF NOT EXISTS flowering_season         TEXT,
  ADD COLUMN IF NOT EXISTS number_of_flowers        TEXT,
  ADD COLUMN IF NOT EXISTS flower_diameter          TEXT,
  ADD COLUMN IF NOT EXISTS inflorescence_type       TEXT,
  ADD COLUMN IF NOT EXISTS petal_characteristics    TEXT,
  ADD COLUMN IF NOT EXISTS sepal_characteristics    TEXT,
  ADD COLUMN IF NOT EXISTS labellum_description     TEXT,
  ADD COLUMN IF NOT EXISTS fragrance                TEXT,
  ADD COLUMN IF NOT EXISTS blooming_stage           TEXT,

  -- Fruit / seeds
  ADD COLUMN IF NOT EXISTS fruit_present            TEXT,
  ADD COLUMN IF NOT EXISTS fruit_type               TEXT,
  ADD COLUMN IF NOT EXISTS seed_capsule_condition   TEXT,

  -- Species value / importance
  ADD COLUMN IF NOT EXISTS ethnobotanical_importance TEXT,
  ADD COLUMN IF NOT EXISTS aesthetic_appeal          TEXT,
  ADD COLUMN IF NOT EXISTS cultivation               TEXT,
  ADD COLUMN IF NOT EXISTS rarity                    TEXT,
  ADD COLUMN IF NOT EXISTS cultural_importance       TEXT,

  -- Extra notes
  ADD COLUMN IF NOT EXISTS unusual_observations      TEXT;

SELECT 'Migration complete — ' || COUNT(*) || ' column(s) now available'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'species_sightings';
