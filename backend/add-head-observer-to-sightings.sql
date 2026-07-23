BEGIN;

-- The submission form's "Head Observer / Researcher Name" field (Page 9) was
-- validated as required but its value was never actually saved anywhere —
-- the insert payload sent `researcher_name`, a column the 3NF migration
-- already dropped from species_sightings (it's derived from researcher_email
-- via a join in the reporting views instead). This gives the field its own
-- real, unambiguous column.
ALTER TABLE species_sightings ADD COLUMN IF NOT EXISTS head_observer_name VARCHAR(255);

COMMIT;
