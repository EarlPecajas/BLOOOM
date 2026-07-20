BEGIN;

-- Number of orchid species observed during this survey/visit (distinct from
-- population_count, which is the individual-plant count for the species
-- this sighting record is actually about).
ALTER TABLE public.species_sightings ADD COLUMN IF NOT EXISTS species_count INTEGER;

COMMIT;
