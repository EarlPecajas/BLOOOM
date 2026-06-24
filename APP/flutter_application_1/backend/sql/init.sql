CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS account_type (
  account_type_id BIGSERIAL PRIMARY KEY,
  account_desc VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS users (
  user_id BIGSERIAL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  gender VARCHAR(50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS location VARCHAR(255);

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS profile_photo_base64 TEXT;

CREATE TABLE IF NOT EXISTS account (
  account_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  username VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  account_type_id BIGINT REFERENCES account_type(account_type_id),
  creation_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS genus (
  genus_id BIGSERIAL PRIMARY KEY,
  genus_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS orchids (
  orchid_id BIGSERIAL PRIMARY KEY,
  sci_name VARCHAR(255) NOT NULL UNIQUE,
  common_name VARCHAR(255),
  genus_id BIGINT REFERENCES genus(genus_id) ON DELETE SET NULL,
  date_discovered TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS province (
  province_id BIGSERIAL PRIMARY KEY,
  province_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS municipality (
  municipality_id BIGSERIAL PRIMARY KEY,
  province_id BIGINT NOT NULL REFERENCES province(province_id) ON DELETE CASCADE,
  municipality_name VARCHAR(255) NOT NULL,
  geom GEOGRAPHY(Polygon, 4326),
  UNIQUE (province_id, municipality_name)
);

CREATE TABLE IF NOT EXISTS mountain (
  mountain_id BIGSERIAL PRIMARY KEY,
  municipality_id BIGINT REFERENCES municipality(municipality_id) ON DELETE SET NULL,
  mountain_name VARCHAR(255) NOT NULL,
  geom GEOGRAPHY(Point, 4326),
  UNIQUE (municipality_id, mountain_name)
);

CREATE TABLE IF NOT EXISTS orchid_location (
  orchid_location_id BIGSERIAL PRIMARY KEY,
  orchid_id BIGINT NOT NULL REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  mountain_id BIGINT REFERENCES mountain(mountain_id) ON DELETE SET NULL,
  geom GEOGRAPHY(Point, 4326) NOT NULL,
  elevation DOUBLE PRECISION,
  notes TEXT,
  date_recorded TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS habitat_information (
  habitat_id BIGSERIAL PRIMARY KEY,
  orchid_location_id BIGINT NOT NULL REFERENCES orchid_location(orchid_location_id) ON DELETE CASCADE,
  altitude VARCHAR(255),
  vertical_distribution VARCHAR(255),
  habitat_type VARCHAR(255),
  micro_habitat VARCHAR(255),
  UNIQUE (orchid_location_id)
);

CREATE TABLE IF NOT EXISTS species_value (
  species_val_id BIGSERIAL PRIMARY KEY,
  orchid_id BIGINT NOT NULL REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  ethnobotanical_value VARCHAR(255),
  horticultural_value VARCHAR(255),
  validity VARCHAR(255),
  UNIQUE (orchid_id)
);

CREATE TABLE IF NOT EXISTS morphological_characteristics (
  morphological_id BIGSERIAL PRIMARY KEY,
  orchid_id BIGINT NOT NULL REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  leaf_type VARCHAR(255),
  flower_color VARCHAR(255),
  flowering_season VARCHAR(255),
  UNIQUE (orchid_id)
);

CREATE TABLE IF NOT EXISTS picture (
  picture_id BIGSERIAL PRIMARY KEY,
  orchid_id BIGINT NOT NULL REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_type VARCHAR(50),
  file_size INTEGER,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  photo_credit VARCHAR(255),
  date_uploaded TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS model_3d (
  model_id BIGSERIAL PRIMARY KEY,
  orchid_id BIGINT NOT NULL REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  format VARCHAR(50),
  date_created TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conservation_status (
  conservation_id BIGSERIAL PRIMARY KEY,
  orchid_id BIGINT NOT NULL REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  conservation_status VARCHAR(20),
  status_desc VARCHAR(255),
  threats VARCHAR(255),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (orchid_id)
);

CREATE INDEX IF NOT EXISTS idx_orchids_sci_name ON orchids (sci_name);
CREATE INDEX IF NOT EXISTS idx_picture_uploaded_at ON picture (date_uploaded DESC);
CREATE INDEX IF NOT EXISTS idx_orchid_location_geom ON orchid_location USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_municipality_geom ON municipality USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mountain_geom ON mountain USING GIST (geom);

INSERT INTO account_type (account_desc)
VALUES ('Researcher'), ('Admin')
ON CONFLICT (account_desc) DO NOTHING;

INSERT INTO genus (genus_name)
VALUES ('Vanda'), ('Abdominea')
ON CONFLICT (genus_name) DO NOTHING;

INSERT INTO orchids (sci_name, common_name, genus_id)
VALUES
  ('Vanda sanderiana', 'Waling-waling', (SELECT genus_id FROM genus WHERE genus_name = 'Vanda')),
  ('Abdominea minimiflora', 'Mini-flower', (SELECT genus_id FROM genus WHERE genus_name = 'Abdominea'))
ON CONFLICT (sci_name)
DO UPDATE SET
  common_name = EXCLUDED.common_name,
  genus_id = COALESCE(EXCLUDED.genus_id, orchids.genus_id);

INSERT INTO province (province_name)
VALUES ('South Cotabato')
ON CONFLICT (province_name) DO NOTHING;

INSERT INTO municipality (province_id, municipality_name, geom)
SELECT
  p.province_id,
  'Polomolok',
  NULL
FROM province p
WHERE p.province_name = 'South Cotabato'
ON CONFLICT (province_id, municipality_name) DO NOTHING;

INSERT INTO mountain (municipality_id, mountain_name, geom)
SELECT
  m.municipality_id,
  'Mt. Busa',
  ST_SetSRID(ST_MakePoint(125.0832, 5.9352), 4326)::geography
FROM municipality m
JOIN province p ON p.province_id = m.province_id
WHERE p.province_name = 'South Cotabato'
  AND m.municipality_name = 'Polomolok'
ON CONFLICT (municipality_id, mountain_name)
DO UPDATE SET geom = EXCLUDED.geom;

INSERT INTO picture (orchid_id, file_url, file_type, file_size, status, photo_credit, date_uploaded)
SELECT
  o.orchid_id,
  seed.file_url,
  seed.file_type,
  seed.file_size,
  seed.status,
  seed.photo_credit,
  seed.date_uploaded
FROM (
  VALUES
    ('Vanda sanderiana', 'https://picsum.photos/seed/vanda-sanderiana-status/200/200', 'image/jpeg', 120450, 'approved', 'Research Team A', '2024-12-01T00:00:00Z'::timestamptz),
    ('Abdominea minimiflora', 'https://picsum.photos/seed/abdominea-minimiflora-status/200/200', 'image/jpeg', 132000, 'pending', 'Research Team B', '2024-12-06T00:00:00Z'::timestamptz)
) AS seed(sci_name, file_url, file_type, file_size, status, photo_credit, date_uploaded)
JOIN orchids o ON o.sci_name = seed.sci_name
WHERE NOT EXISTS (
  SELECT 1
  FROM picture existing
  WHERE existing.orchid_id = o.orchid_id
    AND existing.status = seed.status
    AND existing.date_uploaded = seed.date_uploaded
);

INSERT INTO orchid_location (orchid_id, mountain_id, geom, elevation, notes, date_recorded)
SELECT
  o.orchid_id,
  mountain.mountain_id,
  ST_SetSRID(ST_MakePoint(seed.lng, seed.lat), 4326)::geography,
  seed.elevation,
  seed.notes,
  seed.date_recorded
FROM (
  VALUES
    ('Vanda sanderiana', 'Mt. Busa', 125.0832, 5.9352, 1215.0, 'Observed near Mt. Busa trail.', '2024-12-01T08:30:00Z'::timestamptz),
    ('Abdominea minimiflora', 'Mt. Busa', 125.0861, 5.9380, 1180.0, 'Found in shaded understory.', '2024-12-06T09:15:00Z'::timestamptz)
) AS seed(sci_name, mountain_name, lng, lat, elevation, notes, date_recorded)
JOIN orchids o ON o.sci_name = seed.sci_name
LEFT JOIN mountain ON mountain.mountain_name = seed.mountain_name
WHERE NOT EXISTS (
  SELECT 1
  FROM orchid_location existing
  WHERE existing.orchid_id = o.orchid_id
    AND existing.date_recorded = seed.date_recorded
);

INSERT INTO habitat_information (orchid_location_id, altitude, vertical_distribution, habitat_type, micro_habitat)
SELECT
  ol.orchid_location_id,
  seed.altitude,
  seed.vertical_distribution,
  seed.habitat_type,
  seed.micro_habitat
FROM (
  VALUES
    ('Vanda sanderiana', '1200-1300 masl', 'Montane', 'Forest edge', 'Mossy bark on mature trees'),
    ('Abdominea minimiflora', '1100-1200 masl', 'Lower montane', 'Shaded understory', 'Humus-rich branch pockets')
) AS seed(sci_name, altitude, vertical_distribution, habitat_type, micro_habitat)
JOIN orchids o ON o.sci_name = seed.sci_name
JOIN orchid_location ol ON ol.orchid_id = o.orchid_id
WHERE NOT EXISTS (
  SELECT 1
  FROM habitat_information existing
  WHERE existing.orchid_location_id = ol.orchid_location_id
);

INSERT INTO species_value (orchid_id, ethnobotanical_value, horticultural_value, validity)
SELECT
  o.orchid_id,
  seed.ethnobotanical_value,
  seed.horticultural_value,
  seed.validity
FROM (
  VALUES
    ('Vanda sanderiana', 'Used in local orchid education exhibits', 'High ornamental demand', 'Field verified by team'),
    ('Abdominea minimiflora', 'Contributes to biodiversity documentation', 'Specialist collector interest', 'Confirmed with herbarium references')
) AS seed(sci_name, ethnobotanical_value, horticultural_value, validity)
JOIN orchids o ON o.sci_name = seed.sci_name
ON CONFLICT (orchid_id)
DO UPDATE SET
  ethnobotanical_value = EXCLUDED.ethnobotanical_value,
  horticultural_value = EXCLUDED.horticultural_value,
  validity = EXCLUDED.validity;

INSERT INTO morphological_characteristics (orchid_id, leaf_type, flower_color, flowering_season)
SELECT
  o.orchid_id,
  seed.leaf_type,
  seed.flower_color,
  seed.flowering_season
FROM (
  VALUES
    ('Vanda sanderiana', 'Oblong', 'Pink-violet', 'October to February'),
    ('Abdominea minimiflora', 'Linear', 'Cream-white', 'June to September')
) AS seed(sci_name, leaf_type, flower_color, flowering_season)
JOIN orchids o ON o.sci_name = seed.sci_name
ON CONFLICT (orchid_id)
DO UPDATE SET
  leaf_type = EXCLUDED.leaf_type,
  flower_color = EXCLUDED.flower_color,
  flowering_season = EXCLUDED.flowering_season;

INSERT INTO conservation_status (orchid_id, conservation_status, status_desc, threats)
SELECT
  o.orchid_id,
  seed.conservation_status,
  seed.status_desc,
  seed.threats
FROM (
  VALUES
    ('Vanda sanderiana', 'vulnerable', 'Population monitored annually', 'Habitat loss and over-collection'),
    ('Abdominea minimiflora', 'data_deficient', 'Requires more census records', 'Limited known habitat range')
) AS seed(sci_name, conservation_status, status_desc, threats)
JOIN orchids o ON o.sci_name = seed.sci_name
ON CONFLICT (orchid_id)
DO UPDATE SET
  conservation_status = EXCLUDED.conservation_status,
  status_desc = EXCLUDED.status_desc,
  threats = EXCLUDED.threats,
  updated_at = NOW();
