BEGIN;

-- Free-text catalog fields DENR fills in manually when publishing a species to
-- the catalog. There's no equivalent field anywhere on the researcher
-- submission form, so this data never came from anywhere — orchid_overview
-- previously returned these as hardcoded NULLs, which is why they always
-- exported empty.
ALTER TABLE orchids ADD COLUMN IF NOT EXISTS ethnobotanical_value TEXT;
ALTER TABLE orchids ADD COLUMN IF NOT EXISTS horticultural_value TEXT;
ALTER TABLE orchids ADD COLUMN IF NOT EXISTS cultural_importance TEXT;

-- Replace the NULL placeholders in orchid_overview with the real columns.
DROP VIEW IF EXISTS orchid_overview;

CREATE VIEW orchid_overview AS
SELECT
  o.orchid_id AS id,
  o.sci_name AS name,
  g.genus_name AS genus,
  o.common_name,
  o.endemicity,
  o.ethnobotanical_value AS ethnobotanical,
  o.horticultural_value AS horticulture_value,
  o.cultural_importance,
  p.file_path AS image_url,
  o.model_3d_url,
  CASE
    WHEN lower(coalesce(cs.conservation_status, '')) IN ('critically endangered', 'critically_endangered') THEN 'critically_endangered'
    WHEN lower(coalesce(cs.conservation_status, '')) = 'endangered' THEN 'endangered'
    WHEN lower(coalesce(cs.conservation_status, '')) = 'vulnerable' THEN 'vulnerable'
    WHEN lower(coalesce(cs.conservation_status, '')) IN ('least concern', 'least_concern') THEN 'least_concern'
    ELSE 'unassigned'
  END AS conservation_status_key,
  coalesce(cs.conservation_status, 'Unassigned') AS conservation_status,
  coalesce(o.hidden_fields, '[]'::jsonb) AS hidden_fields
FROM orchids o
JOIN genus g ON g.genus_id = o.genus_id
LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
LEFT JOIN conservation_status cs ON cs.conservation_id = b.conservation_id
LEFT JOIN picture p ON p.picture_id = b.picture_id;

GRANT SELECT ON orchid_overview TO anon, authenticated;

COMMIT;
