BEGIN;

CREATE OR REPLACE VIEW orchid_overview AS
SELECT
  o.orchid_id AS id,
  o.sci_name AS name,
  g.genus_name AS genus,
  o.common_name,
  o.endemicity,
  NULL::text AS ethnobotanical,
  NULL::text AS horticulture_value,
  NULL::text AS cultural_importance,
  p.file_path AS image_url,
  CASE
    WHEN lower(coalesce(cs.conservation_status, '')) IN ('critically endangered', 'critically_endangered') THEN 'critically_endangered'
    WHEN lower(coalesce(cs.conservation_status, '')) = 'endangered' THEN 'endangered'
    WHEN lower(coalesce(cs.conservation_status, '')) = 'vulnerable' THEN 'vulnerable'
    WHEN lower(coalesce(cs.conservation_status, '')) IN ('least concern', 'least_concern') THEN 'least_concern'
    ELSE 'unassigned'
  END AS conservation_status_key,
  coalesce(cs.conservation_status, 'Unassigned') AS conservation_status
FROM orchids o
JOIN genus g ON g.genus_id = o.genus_id
LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
LEFT JOIN conservation_status cs ON cs.conservation_id = b.conservation_id
LEFT JOIN picture p ON p.picture_id = b.picture_id;

GRANT SELECT ON orchid_overview TO anon, authenticated;

COMMIT;
