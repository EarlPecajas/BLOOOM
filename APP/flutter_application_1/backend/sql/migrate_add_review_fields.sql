-- ============================================================
-- BLOOM3D Migration: Add review fields + enable Realtime
-- Run once in Supabase SQL Editor  (Dashboard › SQL Editor)
-- Safe to re-run: uses ADD COLUMN IF NOT EXISTS
-- ============================================================

-- 1. Review fields written by the dashboard after Approve / Reject
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS review_notes  TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at   TIMESTAMPTZ;

-- 2. Enable full-row replication so Supabase Realtime can stream
--    INSERT / UPDATE events to the dashboard in real time.
ALTER TABLE species_sightings REPLICA IDENTITY FULL;

-- 3. Add the table to the default supabase_realtime publication
--    (safe if already a member — the DO block checks first).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'species_sightings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE species_sightings;
  END IF;
END $$;

SELECT 'Migration complete — review_notes, reviewed_at added; Realtime enabled' AS result;
