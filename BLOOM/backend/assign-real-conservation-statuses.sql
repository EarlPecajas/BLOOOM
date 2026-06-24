-- One-time assignment of real conservation statuses for the Mt. Busa orchid
-- catalog (replaces the placeholder/random assignment in
-- assign-conservation-statuses.sql and randomize-conservation-statuses.sql).
--
-- Statuses are based on commonly-cited IUCN / CITES / Philippine DENR
-- DAO 2017-11 classifications. Verify against your own literature review
-- before citing these in a final report:
--   - Vanda sanderiana, Paphiopedilum fowliei: well-documented as
--     Critically Endangered (narrow range, heavy collection pressure).
--   - Phalaenopsis schilleriana: listed Vulnerable under DAO 2017-11.
--   - Trichoglottis brachiata: marked Vulnerable here as a conservative
--     estimate (limited Philippine distribution) — least certain entry,
--     double-check if you have a more specific source.
--   - Dendrobium secundum, Spathoglottis plicata, Aerides quinquevulnera,
--     Coelogyne asperata, Bulbophyllum lobbii, Calanthe triplicata: widespread
--     across the Philippines/SE Asia, generally Least Concern.
--
-- Run in the Supabase SQL Editor (requires elevated privileges that bypass
-- RLS — the public anon key used by the website cannot perform this write).

BEGIN;

UPDATE biogeography b
SET conservation_id = (
  SELECT cs.conservation_id
  FROM conservation_status cs
  WHERE cs.conservation_status = CASE o.sci_name
    WHEN 'Vanda sanderiana'          THEN 'Critically Endangered'
    WHEN 'Paphiopedilum fowliei'     THEN 'Critically Endangered'
    WHEN 'Phalaenopsis schilleriana' THEN 'Vulnerable'
    WHEN 'Trichoglottis brachiata'   THEN 'Vulnerable'
    WHEN 'Dendrobium secundum'       THEN 'Least Concern'
    WHEN 'Spathoglottis plicata'     THEN 'Least Concern'
    WHEN 'Aerides quinquevulnera'    THEN 'Least Concern'
    WHEN 'Coelogyne asperata'        THEN 'Least Concern'
    WHEN 'Bulbophyllum lobbii'       THEN 'Least Concern'
    WHEN 'Calanthe triplicata'       THEN 'Least Concern'
  END
)
FROM orchids o
WHERE b.orchid_id = o.orchid_id
  AND o.sci_name IN (
    'Vanda sanderiana', 'Paphiopedilum fowliei', 'Phalaenopsis schilleriana',
    'Trichoglottis brachiata', 'Dendrobium secundum', 'Spathoglottis plicata',
    'Aerides quinquevulnera', 'Coelogyne asperata', 'Bulbophyllum lobbii',
    'Calanthe triplicata'
  );

COMMIT;
