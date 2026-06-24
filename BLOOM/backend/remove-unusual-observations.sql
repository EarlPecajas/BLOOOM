BEGIN;

ALTER TABLE IF EXISTS species_sightings
  DROP COLUMN IF EXISTS unusual_observations CASCADE;

COMMIT;
