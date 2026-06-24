-- ============================================================
-- BLOOM3D Migration: Make field-survey-specific columns nullable
-- Run once in Supabase SQL Editor  (Dashboard › SQL Editor)
--
-- Field sightings fill all of these. 3D photo uploads only supply
-- orchid name, researcher info, photo URL and review_status — so
-- every other column must accept NULL.
-- Safe to re-run: DROP NOT NULL on an already-nullable column is a no-op.
-- ============================================================

ALTER TABLE species_sightings
  ALTER COLUMN observation_date     DROP NOT NULL,
  ALTER COLUMN observation_time     DROP NOT NULL,
  ALTER COLUMN collection_method    DROP NOT NULL,
  ALTER COLUMN observation_type     DROP NOT NULL,
  ALTER COLUMN voucher_collected    DROP NOT NULL,
  ALTER COLUMN mountain_name        DROP NOT NULL,
  ALTER COLUMN specific_site_zone   DROP NOT NULL,
  ALTER COLUMN latitude             DROP NOT NULL,
  ALTER COLUMN longitude            DROP NOT NULL,
  ALTER COLUMN elevation_meters     DROP NOT NULL,
  ALTER COLUMN habitat_type         DROP NOT NULL,
  ALTER COLUMN microhabitat         DROP NOT NULL,
  ALTER COLUMN leaf_shape           DROP NOT NULL,
  ALTER COLUMN flower_color         DROP NOT NULL,
  ALTER COLUMN life_stage           DROP NOT NULL,
  ALTER COLUMN phenology            DROP NOT NULL,
  ALTER COLUMN population_count     DROP NOT NULL,
  ALTER COLUMN population_status    DROP NOT NULL,
  ALTER COLUMN threat_level         DROP NOT NULL,
  ALTER COLUMN threat_types         DROP NOT NULL,
  ALTER COLUMN institution          DROP NOT NULL,
  ALTER COLUMN team_members         DROP NOT NULL,
  ALTER COLUMN researcher_notes     DROP NOT NULL;

SELECT 'Migration complete — field-survey columns are now nullable' AS result;
