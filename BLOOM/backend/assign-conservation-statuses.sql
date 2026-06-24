BEGIN;

-- Ensure baseline conservation statuses exist.
INSERT INTO conservation_status (conservation_status, status_desc, threats)
VALUES
  ('Critically Endangered', 'Extremely high risk of extinction in the wild.', 'Habitat loss, overcollection, climate pressure'),
  ('Endangered', 'Very high risk of extinction in the wild.', 'Habitat fragmentation, illegal collection, disturbance'),
  ('Vulnerable', 'High risk of extinction in the medium term.', 'Land-use change, invasive species, climate stress'),
  ('Least Concern', 'Lower immediate risk under current assessment.', 'Localized disturbance and habitat pressure')
ON CONFLICT DO NOTHING;

-- Ensure every orchid has a biogeography row.
INSERT INTO biogeography (orchid_id)
SELECT o.orchid_id
FROM orchids o
LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
WHERE b.orchid_id IS NULL;

-- Build a reusable list of conservation IDs.
WITH status_ids AS (
  SELECT
    MAX(CASE WHEN lower(conservation_status) IN ('critically endangered', 'critically_endangered') THEN conservation_id END) AS critically_endangered_id,
    MAX(CASE WHEN lower(conservation_status) = 'endangered' THEN conservation_id END) AS endangered_id,
    MAX(CASE WHEN lower(conservation_status) = 'vulnerable' THEN conservation_id END) AS vulnerable_id,
    MAX(CASE WHEN lower(conservation_status) IN ('least concern', 'least_concern') THEN conservation_id END) AS least_concern_id
  FROM conservation_status
),
assignments AS (
  SELECT
    b.biogeographic_id,
    CASE
      WHEN b.pick < 0.10 THEN s.critically_endangered_id
      WHEN b.pick < 0.35 THEN s.endangered_id
      WHEN b.pick < 0.70 THEN s.vulnerable_id
      ELSE s.least_concern_id
    END AS assigned_conservation_id
  FROM (
    SELECT biogeographic_id, conservation_id, random() AS pick
    FROM biogeography
  ) b
  CROSS JOIN status_ids s
  WHERE b.conservation_id IS NULL
)
UPDATE biogeography b
SET conservation_id = a.assigned_conservation_id
FROM assignments a
WHERE b.biogeographic_id = a.biogeographic_id;

COMMIT;
