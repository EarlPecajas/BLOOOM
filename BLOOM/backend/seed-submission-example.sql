BEGIN;

INSERT INTO "user" (first_name, last_name)
SELECT 'Aljohn Jay L.', 'Saavedra'
WHERE NOT EXISTS (
  SELECT 1 FROM "user" WHERE first_name = 'Aljohn Jay L.' AND last_name = 'Saavedra'
);

INSERT INTO "user" (first_name, last_name)
SELECT 'Kier Mitchel E.', 'Pitogo'
WHERE NOT EXISTS (
  SELECT 1 FROM "user" WHERE first_name = 'Kier Mitchel E.' AND last_name = 'Pitogo'
);

INSERT INTO picture (file_name, file_path, file_type)
VALUES ('approved_vanda_photo.webp', './orchid1.webp', 'image/webp')
ON CONFLICT (file_path) DO NOTHING;

INSERT INTO picture (file_name, file_path, file_type)
VALUES ('revision_dendrobium_photo.jpg', './orchid2.jpg', 'image/jpeg')
ON CONFLICT (file_path) DO NOTHING;

-- Ensure the genus exists.
INSERT INTO genus (genus_name)
VALUES ('Vanda')
ON CONFLICT (genus_name) DO NOTHING;

-- Upsert the species shown in the submissions example.
INSERT INTO orchids (sci_name, genus_id, common_name, endemicity, date_discovered)
SELECT
  'Vanda sanderiana',
  g.genus_id,
  E'Waling-waling\nSander''s Vanda\n---',
  'Not endemic to the Philippines',
  DATE '2024-02-19'
FROM genus g
WHERE g.genus_name = 'Vanda'
ON CONFLICT (sci_name)
DO UPDATE SET
  genus_id = EXCLUDED.genus_id,
  common_name = EXCLUDED.common_name,
  endemicity = EXCLUDED.endemicity,
  date_discovered = EXCLUDED.date_discovered;

-- Ensure a conservation status row exists.
WITH existing_status AS (
  SELECT conservation_id
  FROM conservation_status
  WHERE lower(conservation_status) = 'critically endangered'
  LIMIT 1
), inserted_status AS (
  INSERT INTO conservation_status (conservation_status, status_desc, threats)
  SELECT
    'Critically Endangered',
    'Faces an extremely high risk of extinction in the wild.',
    'Habitat loss, overcollection, and climate pressure'
  WHERE NOT EXISTS (SELECT 1 FROM existing_status)
  RETURNING conservation_id
), status_pick AS (
  SELECT conservation_id FROM existing_status
  UNION ALL
  SELECT conservation_id FROM inserted_status
  LIMIT 1
), existing_value AS (
  SELECT specie_val_id
  FROM specie_value
  WHERE ethnobotanical = 'No recorded ethnobotanical importance.'
    AND horticulture_value = E'Aesthetic Appeal\n- Vibrant\n\nCultivation\n- Adaptable\n- Low Maintenance\n\nRarity\n- Common\n- Native to the Philippines'
    AND cultural_imp = 'The orchid is considered to be the "Queen of Philippine flowers" and is worshiped as a diwata by the indigenous Bagobo people.'
  LIMIT 1
), inserted_value AS (
  INSERT INTO specie_value (ethnobotanical, horticulture_value, cultural_imp)
  SELECT
    'No recorded ethnobotanical importance.',
    E'Aesthetic Appeal\n- Vibrant\n\nCultivation\n- Adaptable\n- Low Maintenance\n\nRarity\n- Common\n- Native to the Philippines',
    'The orchid is considered to be the "Queen of Philippine flowers" and is worshiped as a diwata by the indigenous Bagobo people.'
  WHERE NOT EXISTS (SELECT 1 FROM existing_value)
  RETURNING specie_val_id
), value_pick AS (
  SELECT specie_val_id FROM existing_value
  UNION ALL
  SELECT specie_val_id FROM inserted_value
  LIMIT 1
)
INSERT INTO biogeography (orchid_id, conservation_id, specie_val_id, submission_status, user_id, picture_id)
SELECT
  o.orchid_id,
  sp.conservation_id,
  vp.specie_val_id,
  'approved',
  (SELECT user_id FROM "user" WHERE first_name = 'Aljohn Jay L.' AND last_name = 'Saavedra' ORDER BY user_id LIMIT 1),
  (SELECT picture_id FROM picture WHERE file_path = './orchid1.webp' LIMIT 1)
FROM orchids o
CROSS JOIN status_pick sp
CROSS JOIN value_pick vp
WHERE o.sci_name = 'Vanda sanderiana'
ON CONFLICT (orchid_id)
DO UPDATE SET
  conservation_id = EXCLUDED.conservation_id,
  specie_val_id = EXCLUDED.specie_val_id,
  submission_status = EXCLUDED.submission_status,
  user_id = EXCLUDED.user_id,
  picture_id = EXCLUDED.picture_id;

-- Additional example submission 1: Dendrobium boosii
INSERT INTO genus (genus_name)
VALUES ('Dendrobium')
ON CONFLICT (genus_name) DO NOTHING;

INSERT INTO orchids (sci_name, genus_id, common_name, endemicity, date_discovered)
SELECT
  'Dendrobium boosii',
  g.genus_id,
  'Boos'' Dendrobium',
  'Endemic to Mindanao, Philippines',
  DATE '2024-07-03'
FROM genus g
WHERE g.genus_name = 'Dendrobium'
ON CONFLICT (sci_name)
DO UPDATE SET
  genus_id = EXCLUDED.genus_id,
  common_name = EXCLUDED.common_name,
  endemicity = EXCLUDED.endemicity,
  date_discovered = EXCLUDED.date_discovered;

WITH existing_status AS (
  SELECT conservation_id
  FROM conservation_status
  WHERE lower(conservation_status) = 'endangered'
  LIMIT 1
), inserted_status AS (
  INSERT INTO conservation_status (conservation_status, status_desc, threats)
  SELECT
    'Endangered',
    'Faces a very high risk of extinction in the wild.',
    'Deforestation and illegal collection pressure'
  WHERE NOT EXISTS (SELECT 1 FROM existing_status)
  RETURNING conservation_id
), status_pick AS (
  SELECT conservation_id FROM existing_status
  UNION ALL
  SELECT conservation_id FROM inserted_status
  LIMIT 1
), existing_value AS (
  SELECT specie_val_id
  FROM specie_value
  WHERE ethnobotanical = 'Documented in local ornamental use and small-scale community exhibits.'
    AND horticulture_value = E'Aesthetic Appeal\n- Deep violet blossoms\n\nCultivation\n- Moderate care\n- Performs well in warm humid conditions\n\nRarity\n- Uncommon in trade\n- Important for ex situ conservation collections'
    AND cultural_imp = 'Used in orchid showcases that promote native biodiversity awareness in Mindanao.'
  LIMIT 1
), inserted_value AS (
  INSERT INTO specie_value (ethnobotanical, horticulture_value, cultural_imp)
  SELECT
    'Documented in local ornamental use and small-scale community exhibits.',
    E'Aesthetic Appeal\n- Deep violet blossoms\n\nCultivation\n- Moderate care\n- Performs well in warm humid conditions\n\nRarity\n- Uncommon in trade\n- Important for ex situ conservation collections',
    'Used in orchid showcases that promote native biodiversity awareness in Mindanao.'
  WHERE NOT EXISTS (SELECT 1 FROM existing_value)
  RETURNING specie_val_id
), value_pick AS (
  SELECT specie_val_id FROM existing_value
  UNION ALL
  SELECT specie_val_id FROM inserted_value
  LIMIT 1
)
INSERT INTO biogeography (orchid_id, conservation_id, specie_val_id, submission_status, user_id, picture_id)
SELECT
  o.orchid_id,
  sp.conservation_id,
  vp.specie_val_id,
  'revision',
  (SELECT user_id FROM "user" WHERE first_name = 'Kier Mitchel E.' AND last_name = 'Pitogo' ORDER BY user_id LIMIT 1),
  (SELECT picture_id FROM picture WHERE file_path = './orchid2.jpg' LIMIT 1)
FROM orchids o
CROSS JOIN status_pick sp
CROSS JOIN value_pick vp
WHERE o.sci_name = 'Dendrobium boosii'
ON CONFLICT (orchid_id)
DO UPDATE SET
  conservation_id = EXCLUDED.conservation_id,
  specie_val_id = EXCLUDED.specie_val_id,
  submission_status = EXCLUDED.submission_status,
  user_id = EXCLUDED.user_id,
  picture_id = EXCLUDED.picture_id;

-- Additional example submission 2: Phalaenopsis sanderiana
INSERT INTO genus (genus_name)
VALUES ('Phalaenopsis')
ON CONFLICT (genus_name) DO NOTHING;

INSERT INTO orchids (sci_name, genus_id, common_name, endemicity, date_discovered)
SELECT
  'Phalaenopsis sanderiana',
  g.genus_id,
  'Sander''s Phalaenopsis',
  'Native to Mindanao, Philippines',
  DATE '2024-10-11'
FROM genus g
WHERE g.genus_name = 'Phalaenopsis'
ON CONFLICT (sci_name)
DO UPDATE SET
  genus_id = EXCLUDED.genus_id,
  common_name = EXCLUDED.common_name,
  endemicity = EXCLUDED.endemicity,
  date_discovered = EXCLUDED.date_discovered;

WITH existing_status AS (
  SELECT conservation_id
  FROM conservation_status
  WHERE lower(conservation_status) = 'vulnerable'
  LIMIT 1
), inserted_status AS (
  INSERT INTO conservation_status (conservation_status, status_desc, threats)
  SELECT
    'Vulnerable',
    'Faces a high risk of endangerment in the medium term.',
    'Habitat fragmentation and climate variability'
  WHERE NOT EXISTS (SELECT 1 FROM existing_status)
  RETURNING conservation_id
), status_pick AS (
  SELECT conservation_id FROM existing_status
  UNION ALL
  SELECT conservation_id FROM inserted_status
  LIMIT 1
), existing_value AS (
  SELECT specie_val_id
  FROM specie_value
  WHERE ethnobotanical = 'No direct medicinal record; commonly referenced in biodiversity education.'
    AND horticulture_value = E'Aesthetic Appeal\n- Broad patterned petals\n\nCultivation\n- Best in controlled humidity\n- Requires filtered light\n\nRarity\n- Locally uncommon\n- Frequently targeted for conservation breeding'
    AND cultural_imp = 'Serves as a flagship orchid in regional conservation campaigns and school exhibits.'
  LIMIT 1
), inserted_value AS (
  INSERT INTO specie_value (ethnobotanical, horticulture_value, cultural_imp)
  SELECT
    'No direct medicinal record; commonly referenced in biodiversity education.',
    E'Aesthetic Appeal\n- Broad patterned petals\n\nCultivation\n- Best in controlled humidity\n- Requires filtered light\n\nRarity\n- Locally uncommon\n- Frequently targeted for conservation breeding',
    'Serves as a flagship orchid in regional conservation campaigns and school exhibits.'
  WHERE NOT EXISTS (SELECT 1 FROM existing_value)
  RETURNING specie_val_id
), value_pick AS (
  SELECT specie_val_id FROM existing_value
  UNION ALL
  SELECT specie_val_id FROM inserted_value
  LIMIT 1
)
INSERT INTO biogeography (orchid_id, conservation_id, specie_val_id, submission_status, user_id, picture_id)
SELECT
  o.orchid_id,
  sp.conservation_id,
  vp.specie_val_id,
  'rejected',
  (SELECT user_id FROM "user" WHERE first_name = 'Aljohn Jay L.' AND last_name = 'Saavedra' ORDER BY user_id LIMIT 1),
  NULL
FROM orchids o
CROSS JOIN status_pick sp
CROSS JOIN value_pick vp
WHERE o.sci_name = 'Phalaenopsis sanderiana'
ON CONFLICT (orchid_id)
DO UPDATE SET
  conservation_id = EXCLUDED.conservation_id,
  specie_val_id = EXCLUDED.specie_val_id,
  submission_status = EXCLUDED.submission_status,
  user_id = EXCLUDED.user_id,
  picture_id = EXCLUDED.picture_id;

-- Additional example submission 3: Spathoglottis plicata
INSERT INTO genus (genus_name)
VALUES ('Spathoglottis')
ON CONFLICT (genus_name) DO NOTHING;

INSERT INTO orchids (sci_name, genus_id, common_name, endemicity, date_discovered)
SELECT
  'Spathoglottis plicata',
  g.genus_id,
  'Ground Orchid',
  'Widely distributed in the Philippines',
  DATE '2024-12-27'
FROM genus g
WHERE g.genus_name = 'Spathoglottis'
ON CONFLICT (sci_name)
DO UPDATE SET
  genus_id = EXCLUDED.genus_id,
  common_name = EXCLUDED.common_name,
  endemicity = EXCLUDED.endemicity,
  date_discovered = EXCLUDED.date_discovered;

WITH existing_status AS (
  SELECT conservation_id
  FROM conservation_status
  WHERE lower(conservation_status) IN ('least concern', 'least_concern')
  LIMIT 1
), inserted_status AS (
  INSERT INTO conservation_status (conservation_status, status_desc, threats)
  SELECT
    'Least Concern',
    'Currently at low risk of extinction.',
    'Localized habitat conversion in urban expansion areas'
  WHERE NOT EXISTS (SELECT 1 FROM existing_status)
  RETURNING conservation_id
), status_pick AS (
  SELECT conservation_id FROM existing_status
  UNION ALL
  SELECT conservation_id FROM inserted_status
  LIMIT 1
), existing_value AS (
  SELECT specie_val_id
  FROM specie_value
  WHERE ethnobotanical = 'Occasionally used in landscaping and local ornamental trade.'
    AND horticulture_value = E'Aesthetic Appeal\n- Bright purple flowers\n\nCultivation\n- Easy to maintain\n- Adapts to garden conditions\n\nRarity\n- Commonly cultivated\n- Useful as an outreach species for conservation gardens'
    AND cultural_imp = 'Frequently used in public biodiversity gardens to introduce native orchid conservation.'
  LIMIT 1
), inserted_value AS (
  INSERT INTO specie_value (ethnobotanical, horticulture_value, cultural_imp)
  SELECT
    'Occasionally used in landscaping and local ornamental trade.',
    E'Aesthetic Appeal\n- Bright purple flowers\n\nCultivation\n- Easy to maintain\n- Adapts to garden conditions\n\nRarity\n- Commonly cultivated\n- Useful as an outreach species for conservation gardens',
    'Frequently used in public biodiversity gardens to introduce native orchid conservation.'
  WHERE NOT EXISTS (SELECT 1 FROM existing_value)
  RETURNING specie_val_id
), value_pick AS (
  SELECT specie_val_id FROM existing_value
  UNION ALL
  SELECT specie_val_id FROM inserted_value
  LIMIT 1
)
INSERT INTO biogeography (orchid_id, conservation_id, specie_val_id, submission_status, user_id, picture_id)
SELECT
  o.orchid_id,
  sp.conservation_id,
  vp.specie_val_id,
  'pending',
  (SELECT user_id FROM "user" WHERE first_name = 'Kier Mitchel E.' AND last_name = 'Pitogo' ORDER BY user_id LIMIT 1),
  NULL
FROM orchids o
CROSS JOIN status_pick sp
CROSS JOIN value_pick vp
WHERE o.sci_name = 'Spathoglottis plicata'
ON CONFLICT (orchid_id)
DO UPDATE SET
  conservation_id = EXCLUDED.conservation_id,
  specie_val_id = EXCLUDED.specie_val_id,
  submission_status = EXCLUDED.submission_status,
  user_id = EXCLUDED.user_id,
  picture_id = EXCLUDED.picture_id;

COMMIT;
