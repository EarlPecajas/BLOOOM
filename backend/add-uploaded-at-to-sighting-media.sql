-- Adds a per-photo upload timestamp so the catalog can show "by {photographer}
-- · {date}" captions on contributed photos (previously only the parent
-- species_sightings row had created_at/updated_at, not each individual photo).
--
-- Existing rows backfill to this migration's run time (the schema never
-- tracked true original upload date, so this is the best available default).
--
-- Safe to re-run. Run this in the Supabase SQL Editor.

BEGIN;

ALTER TABLE sighting_media
  ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMIT;
