-- Updates lat/lng for the 10 Mt. Busa orchid sightings with
-- coordinates spread across a wider area (~8–9 km scatter)
-- so each orchid appears at a clearly distinct location on the map.
-- Center reference: Mt. Busa summit ~6.0847, 124.6921
-- Safe to re-run (idempotent).

BEGIN;

-- 1. Aerides quinquevulnera — northeast lower slope, trail, 1050 m
UPDATE species_sightings
SET latitude = 6.1065, longitude = 124.7205, specific_site_zone = 'trail', elevation_meters = 1050.00
WHERE entry_id = 'BLOOM-AQ-001';

-- 2. Bulbophyllum lobbii — north ridge, 1250 m
UPDATE species_sightings
SET latitude = 6.1195, longitude = 124.6955, specific_site_zone = 'ridge', elevation_meters = 1250.00
WHERE entry_id = 'BLOOM-BL-001';

-- 3. Calanthe triplicata — west streamside, 800 m
UPDATE species_sightings
SET latitude = 6.0815, longitude = 124.6520, specific_site_zone = 'streamside', elevation_meters = 800.00
WHERE entry_id = 'BLOOM-CT-001';

-- 4. Coelogyne asperata — southwest lower trail, 650 m
UPDATE species_sightings
SET latitude = 6.0605, longitude = 124.6695, specific_site_zone = 'trail', elevation_meters = 650.00
WHERE entry_id = 'BLOOM-CA-001';

-- 5. Dendrobium secundum — east ridge, 1150 m
UPDATE species_sightings
SET latitude = 6.0960, longitude = 124.7375, specific_site_zone = 'ridge', elevation_meters = 1150.00
WHERE entry_id = 'BLOOM-DS-001';

-- 6. Paphiopedilum fowliei — northwest upper ridge, 1350 m
UPDATE species_sightings
SET latitude = 6.1125, longitude = 124.6645, specific_site_zone = 'ridge', elevation_meters = 1350.00
WHERE entry_id = 'BLOOM-PF-001';

-- 7. Phalaenopsis schilleriana — southeast lower trail, 720 m
UPDATE species_sightings
SET latitude = 6.0565, longitude = 124.7265, specific_site_zone = 'trail', elevation_meters = 720.00
WHERE entry_id = 'BLOOM-PS-001';

-- 8. Spathoglottis plicata — south streamside, 920 m
UPDATE species_sightings
SET latitude = 6.0445, longitude = 124.7025, specific_site_zone = 'streamside', elevation_meters = 920.00
WHERE entry_id = 'BLOOM-SP-001';

-- 9. Trichoglottis brachiata — north-northwest mid trail, 1080 m
UPDATE species_sightings
SET latitude = 6.1085, longitude = 124.6755, specific_site_zone = 'trail', elevation_meters = 1080.00
WHERE entry_id = 'BLOOM-TB-001';

-- 10. Vanda sanderiana — south-southeast lower trail, 580 m
UPDATE species_sightings
SET latitude = 6.0510, longitude = 124.7145, specific_site_zone = 'trail', elevation_meters = 580.00
WHERE entry_id = 'BLOOM-VS-001';

COMMIT;
