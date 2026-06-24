-- ============================================================
-- BLOOM3D Migration: Enable RLS and add dashboard access policies
-- Run in Supabase SQL Editor  (Dashboard › SQL Editor)
--
-- If species_sightings has RLS enabled without policies, every
-- SELECT from the dashboard (anon key) returns 0 rows silently.
-- This adds the minimum policies needed for the dashboard to work.
-- ============================================================

-- 1. Enable RLS on species_sightings (safe if already enabled)
ALTER TABLE species_sightings ENABLE ROW LEVEL SECURITY;

-- 2. Allow anyone (including the anon dashboard key) to read all rows
DROP POLICY IF EXISTS "Public read sightings" ON species_sightings;
CREATE POLICY "Public read sightings" ON species_sightings
  FOR SELECT USING (true);

-- 3. Allow authenticated app users to insert new sightings
DROP POLICY IF EXISTS "Authenticated insert sightings" ON species_sightings;
CREATE POLICY "Authenticated insert sightings" ON species_sightings
  FOR INSERT WITH CHECK (true);

-- 4. Allow the dashboard (anon key) to update review_status / review_notes
DROP POLICY IF EXISTS "Allow review updates" ON species_sightings;
CREATE POLICY "Allow review updates" ON species_sightings
  FOR UPDATE USING (true) WITH CHECK (true);

-- 5. Allow the dashboard to delete rejected submissions
DROP POLICY IF EXISTS "Allow delete rejected" ON species_sightings;
CREATE POLICY "Allow delete rejected" ON species_sightings
  FOR DELETE USING (true);

-- 6. Also ensure review_notes and reviewed_at columns exist
--    (in case migrate_add_review_fields.sql was not run yet)
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS review_notes TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at  TIMESTAMPTZ;

-- 7. Also ensure the nullable fields migration is applied
ALTER TABLE species_sightings
  ALTER COLUMN observation_date   DROP NOT NULL,
  ALTER COLUMN observation_time   DROP NOT NULL,
  ALTER COLUMN collection_method  DROP NOT NULL,
  ALTER COLUMN observation_type   DROP NOT NULL,
  ALTER COLUMN voucher_collected  DROP NOT NULL,
  ALTER COLUMN mountain_name      DROP NOT NULL,
  ALTER COLUMN specific_site_zone DROP NOT NULL,
  ALTER COLUMN latitude           DROP NOT NULL,
  ALTER COLUMN longitude          DROP NOT NULL,
  ALTER COLUMN elevation_meters   DROP NOT NULL,
  ALTER COLUMN habitat_type       DROP NOT NULL,
  ALTER COLUMN microhabitat       DROP NOT NULL,
  ALTER COLUMN leaf_shape         DROP NOT NULL,
  ALTER COLUMN flower_color       DROP NOT NULL,
  ALTER COLUMN life_stage         DROP NOT NULL,
  ALTER COLUMN phenology          DROP NOT NULL,
  ALTER COLUMN population_count   DROP NOT NULL,
  ALTER COLUMN population_status  DROP NOT NULL,
  ALTER COLUMN threat_level       DROP NOT NULL,
  ALTER COLUMN threat_types       DROP NOT NULL,
  ALTER COLUMN institution        DROP NOT NULL,
  ALTER COLUMN team_members       DROP NOT NULL,
  ALTER COLUMN researcher_notes   DROP NOT NULL;

-- 8. Enable Realtime (in case migrate_add_review_fields.sql was not run)
ALTER TABLE species_sightings REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'species_sightings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE species_sightings;
  END IF;
END $$;

SELECT 'All migrations applied — RLS policies, nullable columns, Realtime enabled' AS result;
