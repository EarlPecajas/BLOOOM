BEGIN;

-- Add genus column to species_sightings (was missing from original schema)
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS genus VARCHAR(120);

-- Add local_names column for separate local/indigenous name storage
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS local_names JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Extend review_status CHECK constraint to allow 'draft'
ALTER TABLE species_sightings
  DROP CONSTRAINT IF EXISTS species_sightings_review_status_check;

ALTER TABLE species_sightings
  ADD CONSTRAINT species_sightings_review_status_check
  CHECK (lower(review_status) IN ('approved', 'rejected', 'revision', 'pending', 'draft'));

COMMIT;
