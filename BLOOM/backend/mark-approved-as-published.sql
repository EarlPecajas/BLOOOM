-- Mark all currently approved submissions as catalog_published = true.
-- Run once in Supabase SQL Editor to sync existing data.

UPDATE species_sightings
SET catalog_published = true
WHERE lower(trim(review_status)) = 'approved'
  AND (catalog_published IS NULL OR catalog_published = false);
