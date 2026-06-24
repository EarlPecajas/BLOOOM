BEGIN;

ALTER TABLE species_sightings
  ALTER COLUMN whole_plant_photo_path TYPE jsonb USING (
    CASE
      WHEN whole_plant_photo_path IS NULL OR trim(whole_plant_photo_path) = '' THEN '[]'::jsonb
      ELSE to_jsonb(array[whole_plant_photo_path])
    END
  );

ALTER TABLE species_sightings
  ALTER COLUMN closeup_flower_photo_path TYPE jsonb USING (
    CASE
      WHEN closeup_flower_photo_path IS NULL OR trim(closeup_flower_photo_path) = '' THEN '[]'::jsonb
      ELSE to_jsonb(array[closeup_flower_photo_path])
    END
  );

ALTER TABLE species_sightings
  ALTER COLUMN habitat_photo_path TYPE jsonb USING (
    CASE
      WHEN habitat_photo_path IS NULL OR trim(habitat_photo_path) = '' THEN '[]'::jsonb
      ELSE to_jsonb(array[habitat_photo_path])
    END
  );

-- Keep photo_3d_path column but convert to jsonb (may be empty)
ALTER TABLE species_sightings
  ALTER COLUMN photo_3d_path TYPE jsonb USING (
    CASE
      WHEN photo_3d_path IS NULL OR trim(photo_3d_path) = '' THEN '[]'::jsonb
      ELSE to_jsonb(array[photo_3d_path])
    END
  );

ALTER TABLE species_sightings
  ALTER COLUMN video_path TYPE jsonb USING (
    CASE
      WHEN video_path IS NULL OR trim(video_path) = '' THEN '[]'::jsonb
      ELSE to_jsonb(array[video_path])
    END
  );

COMMIT;
