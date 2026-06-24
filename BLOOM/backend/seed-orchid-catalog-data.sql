BEGIN;

-- =====================================================================
-- SEED: Orchid catalog sample data for Mt. Busa documentation display.
-- All sightings use the same template values — this is sample data only.
-- Safe to re-run: uses ON CONFLICT DO NOTHING throughout.
-- =====================================================================

-- 1. Ensure the four baseline conservation status rows exist
INSERT INTO conservation_status (conservation_status, status_desc, threats)
SELECT 'Critically Endangered', 'Extremely high risk of extinction in the wild.', 'Habitat loss, overcollection, climate pressure'
WHERE NOT EXISTS (
  SELECT 1 FROM conservation_status WHERE lower(conservation_status) IN ('critically endangered','critically_endangered')
);

INSERT INTO conservation_status (conservation_status, status_desc, threats)
SELECT 'Endangered', 'Very high risk of extinction in the wild.', 'Habitat fragmentation, illegal collection, disturbance'
WHERE NOT EXISTS (
  SELECT 1 FROM conservation_status WHERE lower(conservation_status) = 'endangered'
);

INSERT INTO conservation_status (conservation_status, status_desc, threats)
SELECT 'Vulnerable', 'High risk of extinction in the medium term.', 'Land-use change, invasive species, climate stress'
WHERE NOT EXISTS (
  SELECT 1 FROM conservation_status WHERE lower(conservation_status) = 'vulnerable'
);

INSERT INTO conservation_status (conservation_status, status_desc, threats)
SELECT 'Least Concern', 'Lower immediate risk under current assessment.', 'Localized disturbance and habitat pressure'
WHERE NOT EXISTS (
  SELECT 1 FROM conservation_status WHERE lower(conservation_status) IN ('least concern','least_concern')
);

-- 2. Ensure every orchid has a biogeography row
INSERT INTO biogeography (orchid_id)
SELECT o.orchid_id
FROM orchids o
LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
WHERE b.orchid_id IS NULL
ON CONFLICT (orchid_id) DO NOTHING;

-- 3. Set all orchids to "Vulnerable" for sample catalog display
UPDATE biogeography
SET conservation_id = (
  SELECT conservation_id
  FROM conservation_status
  WHERE lower(conservation_status) = 'vulnerable'
  ORDER BY conservation_id ASC
  LIMIT 1
);

-- 4. Update all named orchids (exclude unidentified "sp." entries)
--    common_name = genus name + " Orchid",  endemicity = Philippine Endemic
UPDATE orchids o
SET
  common_name  = g.genus_name || ' Orchid',
  endemicity   = 'Philippine Endemic'
FROM genus g
WHERE o.genus_id = g.genus_id
  AND o.sci_name NOT LIKE '% sp.'
  AND o.sci_name NOT LIKE '% sp. %';

-- 5. Insert one approved sighting per named orchid (same template for all)
INSERT INTO species_sightings (
  entry_id,
  scientific_name,
  genus,
  common_names,
  local_names,
  identification_confidence,
  observation_date,
  observation_type,
  mountain_name,
  specific_site_zone,
  latitude,
  longitude,
  elevation_meters,
  habitat_type,
  microhabitat,
  growth_substrate,
  canopy_cover_percent,
  light_exposure,
  nearby_water_source,
  plant_height_cm,
  pseudobulb_present,
  leaf_count,
  leaf_shape,
  leaf_textures,
  leaf_arrangement,
  leaf_length_cm,
  leaf_width_cm,
  flower_color,
  flower_count,
  flower_diameter_cm,
  inflorescence_type,
  fragrance,
  blooming_stage,
  flowering_season,
  population_status,
  threat_level,
  threat_types,
  researcher_name,
  researcher_email,
  institution,
  team_members,
  researcher_notes,
  review_status
)
SELECT
  'SEED-MBUS-' || LPAD(ROW_NUMBER() OVER (ORDER BY o.sci_name)::text, 3, '0'),
  o.sci_name,
  g.genus_name,
  jsonb_build_array(g.genus_name || ' Orchid'),
  '[]'::jsonb,
  'Confirmed',
  '2024-03-15'::date,
  'Visual',
  'Mt. Busa',
  'Northern Slope Trail',
  6.2333,
  124.7000,
  1200.00,
  'Montane Forest',
  'Tree trunk',
  'tree bark',
  75.00,
  'Partial Shade',
  'Permanent stream 50m',
  35.00,
  TRUE,
  5,
  'elliptic',
  '["leathery","smooth"]'::jsonb,
  'distichous',
  12.50,
  4.20,
  'white with purple markings',
  5,
  2.50,
  'raceme',
  'mild',
  'full bloom',
  'March-May',
  'Stable',
  'Vulnerable',
  '["Habitat loss","Illegal collection"]'::jsonb,
  'Dr. Maria Santos',
  'msantos@msugensan.edu.ph',
  'Mindanao State University - General Santos',
  'Dr. M. Santos, Dr. J. Reyes, Ms. A. Cruz',
  'Sample sighting record for Mt. Busa orchid documentation project.',
  'approved'
FROM orchids o
JOIN genus g ON g.genus_id = o.genus_id
WHERE o.sci_name NOT LIKE '% sp.'
  AND o.sci_name NOT LIKE '% sp. %'
ON CONFLICT (entry_id) DO NOTHING;

COMMIT;
