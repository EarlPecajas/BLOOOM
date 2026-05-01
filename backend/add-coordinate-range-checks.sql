BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM species_sightings
    WHERE latitude < -90 OR latitude > 90
  ) THEN
    UPDATE species_sightings
    SET latitude = GREATEST(LEAST(latitude, 90), -90)
    WHERE latitude < -90 OR latitude > 90;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'species_sightings_latitude_range_chk'
  ) THEN
    ALTER TABLE species_sightings
      ADD CONSTRAINT species_sightings_latitude_range_chk
      CHECK (latitude BETWEEN -90 AND 90);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM species_sightings
    WHERE longitude < -180 OR longitude > 180
  ) THEN
    UPDATE species_sightings
    SET longitude = GREATEST(LEAST(longitude, 180), -180)
    WHERE longitude < -180 OR longitude > 180;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'species_sightings_longitude_range_chk'
  ) THEN
    ALTER TABLE species_sightings
      ADD CONSTRAINT species_sightings_longitude_range_chk
      CHECK (longitude BETWEEN -180 AND 180);
  END IF;
END $$;

COMMIT;
