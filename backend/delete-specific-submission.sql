-- Delete a specific submission.
-- Step 1: Run the SELECT to confirm the right row.
-- Step 2: Uncomment and run the DELETE.

SELECT sighting_id, scientific_name, researcher_name, researcher_email, observation_date, review_status, created_at
FROM species_sightings
WHERE lower(trim(scientific_name)) LIKE '%acriopsis liliifolia%'
  AND (observation_date = '2026-05-13' OR created_at::date = '2026-05-13');

-- Confirmed? Run this:
/*
DELETE FROM species_sightings
WHERE lower(trim(scientific_name)) LIKE '%acriopsis liliifolia%'
  AND (observation_date = '2026-05-13' OR created_at::date = '2026-05-13');
*/
