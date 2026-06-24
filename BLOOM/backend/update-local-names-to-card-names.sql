-- Updates local_names for the 10 Mt. Busa orchid sightings to match
-- exactly the names shown on the catalog cards.
-- Replaces the previous Filipino local names.
-- Safe to re-run (idempotent).

BEGIN;

-- 1. Aerides quinquevulnera → "Five-spotted Aerides"
UPDATE species_sightings
SET local_names = '["Five-spotted Aerides"]'::jsonb
WHERE entry_id = 'BLOOM-AQ-001';

-- 2. Bulbophyllum lobbii → "Lobby's Bulbophyllum"
UPDATE species_sightings
SET local_names = '["Lobby''s Bulbophyllum"]'::jsonb
WHERE entry_id = 'BLOOM-BL-001';

-- 3. Calanthe triplicata → "White Calanthe"
UPDATE species_sightings
SET local_names = '["White Calanthe"]'::jsonb
WHERE entry_id = 'BLOOM-CT-001';

-- 4. Coelogyne asperata → "Rough Coelogyne"
UPDATE species_sightings
SET local_names = '["Rough Coelogyne"]'::jsonb
WHERE entry_id = 'BLOOM-CA-001';

-- 5. Dendrobium secundum → "Toothbrush Orchid"
UPDATE species_sightings
SET local_names = '["Toothbrush Orchid"]'::jsonb
WHERE entry_id = 'BLOOM-DS-001';

-- 6. Paphiopedilum fowliei → "Fowlie's Slipper Orchid"
UPDATE species_sightings
SET local_names = '["Fowlie''s Slipper Orchid"]'::jsonb
WHERE entry_id = 'BLOOM-PF-001';

-- 7. Phalaenopsis schilleriana → "Schiller's Moth Orchid"
UPDATE species_sightings
SET local_names = '["Schiller''s Moth Orchid"]'::jsonb
WHERE entry_id = 'BLOOM-PS-001';

-- 8. Spathoglottis plicata → "Philippine Ground Orchid"
UPDATE species_sightings
SET local_names = '["Philippine Ground Orchid"]'::jsonb
WHERE entry_id = 'BLOOM-SP-001';

-- 9. Trichoglottis brachiata → "Philippine Trichoglottis"
UPDATE species_sightings
SET local_names = '["Philippine Trichoglottis"]'::jsonb
WHERE entry_id = 'BLOOM-TB-001';

-- 10. Vanda sanderiana → "Waling-waling"
UPDATE species_sightings
SET local_names = '["Waling-waling"]'::jsonb
WHERE entry_id = 'BLOOM-VS-001';

COMMIT;
