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
JOIN genus g ON g.genus_id = o.genus_id
JOIN picture p ON p.file_path = CASE
  WHEN g.genus_name IN ('Acanthophippium','Acriopsis','Agrostophyllum','Anoectochilus','Appendicula','Blepharoglossum','Brachypeza','Bryobium','Bulbophyllum','Calanthe','Cephalantheropsis','Cheirostylis','Coelogyne') THEN './orchid1.webp'
  WHEN g.genus_name IN ('Corymborkis','Cryptostylis','Cylindrolobus','Cymboglossum','Cystorchis','Dendrobium','Dendrochilum','Dienia','Epiblastus','Epipogium','Erythrodes','Grammatophyllum','Lepidogyne') THEN './orchid2.jpg'
  WHEN g.genus_name IN ('Mycaranthes','Oberonia','Octarrhena','Odontochilus','Oxystophyllum','Paraphaius','Peristylus','Phaius','Phalaenopsis','Pholidota','Phreatia','Pinalia','Podochilus') THEN './orchid3.webp'
  ELSE './ghost orchid.webp'
END
ON CONFLICT (orchid_id)
DO UPDATE SET
  picture_id = EXCLUDED.picture_id;