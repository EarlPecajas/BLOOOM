-- ============================================================
-- CLEANUP: Keep only the final 10 orchids and their data
-- Run in Supabase SQL Editor.
-- STEP 1: Run the SELECT previews first to confirm what will be removed.
-- STEP 2: Uncomment and run the DELETE block.
-- ============================================================

-- Final 10 scientific names to KEEP:
--   Aerides quinquevulnera
--   Bulbophyllum lobbii
--   Calanthe triplicata
--   Coelogyne asperata
--   Dendrobium secundum
--   Paphiopedilum fowliei
--   Phalaenopsis schilleriana
--   Spathoglottis plicata
--   Trichoglottis brachiata
--   Vanda sanderiana

-- ── PREVIEW: orchid records that will be deleted ────────────
SELECT orchid_id, sci_name
FROM orchids
WHERE sci_name NOT IN (
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
)
ORDER BY sci_name;

-- ── PREVIEW: sightings that will be deleted ─────────────────
SELECT sighting_id, scientific_name, review_status, created_at
FROM species_sightings
WHERE TRIM(scientific_name) NOT IN (
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
)
ORDER BY scientific_name;

-- ============================================================
-- DELETE BLOCK — uncomment after reviewing the previews above
-- ============================================================

/*
BEGIN;

-- 1. Delete sightings not belonging to the final 10
DELETE FROM species_sightings
WHERE TRIM(scientific_name) NOT IN (
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
);

-- 2. Delete orchids not in the final 10
--    (biogeography rows cascade-delete automatically via ON DELETE CASCADE)
DELETE FROM orchids
WHERE sci_name NOT IN (
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
);

COMMIT;
*/
