-- Adds 4 extra approved sightings for every species that already has one,
-- spread across nearby Mt. Busa locations (centred on 6.109410, 124.663094).
-- Deletes any previously seeded extras first, then re-inserts clean.
-- Run this in the Supabase SQL Editor.

-- Remove previously seeded extras so re-running always gives fresh coords
DELETE FROM species_sightings WHERE entry_id LIKE 'extra-%';

INSERT INTO species_sightings (
  entry_id, researcher_name, institution,
  scientific_name, common_names, identification_confidence,
  observation_date,
  mountain_name, specific_site_zone,
  latitude, longitude, elevation_meters,
  habitat_type, microhabitat, growth_substrate,
  flower_color, blooming_stage,
  population_status, threat_level,
  leaf_textures, threat_types,
  review_status
)
SELECT
  'extra-' || lower(regexp_replace(base.scientific_name, '\s+', '-', 'g')) || '-' || off.n,
  COALESCE(base.researcher_name, 'BLOOM Research Team'),
  COALESCE(base.institution,     'MSU-Gensan'),
  base.scientific_name,
  COALESCE(base.common_names, '[]'::jsonb),
  COALESCE(base.identification_confidence, 'Confirmed'),
  COALESCE(base.observation_date, '2025-03-15'::date),
  COALESCE(base.mountain_name, 'Mt. Busa'),
  off.site,
  -- Use the sighting's own coords if valid, otherwise fall back to Mt. Busa summit
  COALESCE(NULLIF(base.latitude,  0), 6.109410)  + off.dlat,
  COALESCE(NULLIF(base.longitude, 0), 124.663094) + off.dlng,
  COALESCE(base.elevation_meters, 1150) + off.elev_add,
  COALESCE(base.habitat_type, 'Montane Forest'),
  base.microhabitat,
  base.growth_substrate,
  base.flower_color,
  base.blooming_stage,
  base.population_status,
  base.threat_level,
  '[]'::jsonb,
  '[]'::jsonb,
  'approved'
FROM (
  -- one representative row per species (the original, non-extra sighting)
  SELECT DISTINCT ON (lower(scientific_name))
    scientific_name, common_names, identification_confidence,
    observation_date, mountain_name,
    latitude, longitude, elevation_meters,
    habitat_type, microhabitat, growth_substrate,
    flower_color, blooming_stage,
    population_status, threat_level,
    researcher_name, institution
  FROM species_sightings
  WHERE lower(review_status) = 'approved'
    AND entry_id NOT LIKE 'extra-%'
  ORDER BY lower(scientific_name), sighting_id ASC
) base
CROSS JOIN (VALUES
  (1,  0.0083,  0.0121,  40, 'North Ridge Trail'),
  (2, -0.0147,  0.0063, -30, 'East Slope Zone'),
  (3,  0.0201, -0.0097,  90, 'Upper Forest Belt'),
  (4, -0.0069, -0.0182, -55, 'West Ravine Area')
) AS off(n, dlat, dlng, elev_add, site);
