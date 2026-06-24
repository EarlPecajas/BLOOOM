-- Migration: add common_name column to existing species_sightings table
BEGIN;

ALTER TABLE IF EXISTS species_sightings
  ADD COLUMN IF NOT EXISTS common_name VARCHAR(255);

COMMIT;
