BEGIN;

-- Same class of bug as head_observer_name: the submission form's
-- "Institution / Organization" field is validated/collected but its value is
-- discarded. species_sightings.institution was dropped by the 3NF migration
-- in favor of deriving it from user_id -> affiliation_id -> affiliation_name,
-- but user_id is never actually populated at submission time (both submit
-- paths hardcode it to null), so that derivation never resolves anything.
-- Give the typed value its own real column instead of losing it.
ALTER TABLE species_sightings ADD COLUMN IF NOT EXISTS institution_name VARCHAR(255);

COMMIT;
