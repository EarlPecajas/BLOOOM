-- Removes all species_sightings rows for the 10 Mt. Busa orchids
-- EXCEPT the official BLOOM-XX-001 seed entries.
-- This ensures exactly 1 sighting per orchid on the detail page.
-- Safe to re-run (idempotent).

BEGIN;

DELETE FROM species_sightings
WHERE scientific_name ILIKE ANY (ARRAY[
  'Aerides quinquevulnera',
  'Bulbophyllum lobbii',
  'Calanthe triplicata',
  'Coelogyne asperata',
  'Dendrobium secundum',
  'Paphiopedilum fowliei',
  'Phalaenopsis schilleriana',
  'Spathoglottis plicata',
  'Trichoglottis brachiata',
  'Vanda sanderiana'
])
AND entry_id NOT IN (
  'BLOOM-AQ-001',
  'BLOOM-BL-001',
  'BLOOM-CT-001',
  'BLOOM-CA-001',
  'BLOOM-DS-001',
  'BLOOM-PF-001',
  'BLOOM-PS-001',
  'BLOOM-SP-001',
  'BLOOM-TB-001',
  'BLOOM-VS-001'
);

COMMIT;
