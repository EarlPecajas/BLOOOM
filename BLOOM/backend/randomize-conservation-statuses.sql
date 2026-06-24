-- Randomize conservation status for ALL orchids in biogeography.
-- Distribution: ~10% CR, ~25% EN, ~35% VU, ~30% LC
-- Run this in the Supabase SQL Editor.

UPDATE biogeography b
SET conservation_id = cs.new_id
FROM (
  SELECT
    b2.biogeographic_id,
    CASE
      WHEN b2.r < 0.10 THEN cr.conservation_id
      WHEN b2.r < 0.35 THEN en.conservation_id
      WHEN b2.r < 0.70 THEN vu.conservation_id
      ELSE                   lc.conservation_id
    END AS new_id
  FROM (SELECT biogeographic_id, random() AS r FROM biogeography) b2
  CROSS JOIN (SELECT conservation_id FROM conservation_status WHERE lower(conservation_status) LIKE '%critical%'  LIMIT 1) cr
  CROSS JOIN (SELECT conservation_id FROM conservation_status WHERE lower(conservation_status) = 'endangered'     LIMIT 1) en
  CROSS JOIN (SELECT conservation_id FROM conservation_status WHERE lower(conservation_status) = 'vulnerable'     LIMIT 1) vu
  CROSS JOIN (SELECT conservation_id FROM conservation_status WHERE lower(conservation_status) LIKE '%least%'     LIMIT 1) lc
) cs
WHERE b.biogeographic_id = cs.biogeographic_id;
