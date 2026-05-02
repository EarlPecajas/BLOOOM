BEGIN;

-- View exposing full, non-public fields for authenticated (DENR) users only
CREATE OR REPLACE VIEW denr_approved_sightings AS
SELECT
  s.*
FROM species_sightings s
WHERE lower(coalesce(s.review_status, '')) = 'approved';

GRANT SELECT ON denr_approved_sightings TO authenticated;

COMMIT;
