BEGIN;

-- Endemic to Philippines flag
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS endemic_to_philippines VARCHAR(10);

-- Photographer names per photo category
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS whole_plant_photographer VARCHAR(255);

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS closeup_flower_photographer VARCHAR(255);

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS habitat_photographer VARCHAR(255);

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS photo_3d_photographer VARCHAR(255);

-- Related study (title, link, file URL stored as JSON string)
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS related_study TEXT;

COMMIT;
