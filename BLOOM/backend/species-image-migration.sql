INSERT INTO picture (file_name, file_path, file_type)
VALUES
  ('orchid1.webp', './orchid1.webp', 'image/webp'),
  ('orchid2.jpg', './orchid2.jpg', 'image/jpeg'),
  ('orchid3.webp', './orchid3.webp', 'image/webp'),
  ('ghost orchid.webp', './ghost orchid.webp', 'image/webp')
ON CONFLICT (file_path)
DO UPDATE SET
  file_name = EXCLUDED.file_name,
  file_type = EXCLUDED.file_type,
  date_uploaded = NOW();

INSERT INTO biogeography (orchid_id, picture_id)
SELECT
  o.orchid_id,
  p.picture_id
FROM orchids o
JOIN picture p ON p.file_path = CASE o.sci_name
  WHEN 'Dendrobium boosii' THEN './orchid1.webp'
  WHEN 'Phalaenopsis mariae' THEN './orchid2.jpg'
  WHEN 'Vanda cootesii' THEN './orchid3.webp'
  WHEN 'Taeniophyllum philippinense' THEN './ghost orchid.webp'
  ELSE NULL
END
ON CONFLICT (orchid_id)
DO UPDATE SET
  picture_id = EXCLUDED.picture_id;