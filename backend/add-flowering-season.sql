BEGIN;

ALTER TABLE species_sightings
ADD COLUMN IF NOT EXISTS flowering_season VARCHAR(60);

COMMIT;