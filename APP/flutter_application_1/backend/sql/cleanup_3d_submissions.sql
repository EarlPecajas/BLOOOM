-- ============================================================
-- BLOOM3D Cleanup: Remove all 3D image submissions
-- Run in Supabase SQL Editor  (Dashboard › SQL Editor)
-- ============================================================

-- 1. Delete any species_sightings rows that were created by the
--    3D upload flow (entry IDs prefixed with 'BLOOM-3D-')
DELETE FROM species_sightings
WHERE entry_id LIKE 'BLOOM-3D-%';

-- 2. Report remaining rows to confirm
SELECT COUNT(*) AS remaining_sightings FROM species_sightings;

-- ──────────────────────────────────────────────────────────────
-- Storage cleanup (run in Supabase SQL Editor using storage schema)
-- Deletes every file inside the 3d_images/ folder of bloom-uploads
-- ──────────────────────────────────────────────────────────────
DELETE FROM storage.objects
WHERE bucket_id = 'bloom-uploads'
  AND name LIKE '3d_images/%';

-- 3. Confirm storage is empty
SELECT COUNT(*) AS remaining_3d_files
FROM storage.objects
WHERE bucket_id = 'bloom-uploads'
  AND name LIKE '3d_images/%';
