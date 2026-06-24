-- ============================================================
-- BLOOM3D Seed v1 — 1 sighting per species for 10 Mt. Busa orchids
--
-- HOW TO RUN (in order):
--   1. Run upload_seed_images.ps1 first to push images to Storage
--      .\upload_seed_images.ps1 -ServiceRoleKey "eyJ..."
--   2. Then paste this entire file into Supabase SQL Editor and Run
--
-- What this does (mirrors exactly what the Bloom3D app does):
--   • Creates genus → orchid catalog entries (orchids table)
--   • Creates 1 species_sightings row per species (10 total)
--   • Stores full Supabase public URLs for all photos
--   • Links catalog hero images via picture + biogeography tables
--     so the orchid catalog card shows a photo
-- ============================================================


-- ============================================================
-- STEP 1: Schema setup (safe to re-run — uses IF NOT EXISTS)
-- ============================================================

CREATE TABLE IF NOT EXISTS biogeography (
  biogeography_id   BIGSERIAL    PRIMARY KEY,
  orchid_id         BIGINT       NOT NULL REFERENCES orchids(orchid_id) ON DELETE CASCADE,
  picture_id        BIGINT,
  submission_status TEXT         NOT NULL DEFAULT 'approved',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

ALTER TABLE picture
  ADD COLUMN IF NOT EXISTS orchid_id BIGINT,
  ADD COLUMN IF NOT EXISTS file_path TEXT,
  ADD COLUMN IF NOT EXISTS file_type TEXT,
  ADD COLUMN IF NOT EXISTS file_url TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.key_column_usage kcu
    JOIN information_schema.table_constraints tc
      ON kcu.constraint_name = tc.constraint_name
      AND kcu.table_schema = tc.table_schema
    WHERE kcu.table_schema = 'public'
      AND kcu.table_name = 'picture'
      AND kcu.column_name = 'orchid_id'
      AND tc.constraint_type = 'FOREIGN KEY'
  ) THEN
    EXECUTE 'ALTER TABLE picture ADD CONSTRAINT picture_orchid_id_fkey FOREIGN KEY (orchid_id) REFERENCES orchids(orchid_id) ON DELETE SET NULL';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.key_column_usage kcu
    JOIN information_schema.table_constraints tc
      ON kcu.constraint_name = tc.constraint_name
      AND kcu.table_schema = tc.table_schema
    WHERE kcu.table_schema = 'public'
      AND kcu.table_name = 'biogeography'
      AND kcu.column_name = 'picture_id'
      AND tc.constraint_type = 'FOREIGN KEY'
  ) THEN
    EXECUTE 'ALTER TABLE biogeography ADD CONSTRAINT biogeography_picture_id_fkey FOREIGN KEY (picture_id) REFERENCES picture(picture_id) ON DELETE SET NULL';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'picture'
      AND column_name = 'orchid_id' AND is_nullable = 'NO'
  ) THEN
    EXECUTE 'ALTER TABLE picture ALTER COLUMN orchid_id DROP NOT NULL';
  END IF;
END $$;

-- Widen VARCHAR columns to TEXT
DO $$
DECLARE
  denr_view_def TEXT;
  public_view_def TEXT;
  col_record RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_views WHERE schemaname = 'public' AND viewname = 'denr_approved_sightings') THEN
    SELECT pg_get_viewdef('public.denr_approved_sightings', true) INTO denr_view_def;
    EXECUTE 'DROP VIEW public.denr_approved_sightings';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_views WHERE schemaname = 'public' AND viewname = 'public_approved_sightings') THEN
    SELECT pg_get_viewdef('public.public_approved_sightings', true) INTO public_view_def;
    EXECUTE 'DROP VIEW public.public_approved_sightings';
  END IF;
  FOR col_record IN
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'species_sightings' AND data_type = 'character varying'
  LOOP
    EXECUTE format('ALTER TABLE species_sightings ALTER COLUMN %I TYPE TEXT', col_record.column_name);
  END LOOP;
  IF denr_view_def IS NOT NULL THEN EXECUTE 'CREATE VIEW public.denr_approved_sightings AS ' || denr_view_def; END IF;
  IF public_view_def IS NOT NULL THEN EXECUTE 'CREATE VIEW public.public_approved_sightings AS ' || public_view_def; END IF;
END $$;

-- Ensure all columns the INSERT uses exist
ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS entry_id                  TEXT,
  ADD COLUMN IF NOT EXISTS researcher_email          TEXT,
  ADD COLUMN IF NOT EXISTS researcher_name           TEXT,
  ADD COLUMN IF NOT EXISTS observation_date          TEXT,
  ADD COLUMN IF NOT EXISTS observation_time          TEXT,
  ADD COLUMN IF NOT EXISTS collection_method         TEXT,
  ADD COLUMN IF NOT EXISTS observation_type          TEXT,
  ADD COLUMN IF NOT EXISTS voucher_collected         BOOLEAN,
  ADD COLUMN IF NOT EXISTS mountain_name             TEXT,
  ADD COLUMN IF NOT EXISTS specific_site_zone        TEXT,
  ADD COLUMN IF NOT EXISTS latitude                  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude                 DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS elevation_meters          DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS habitat_type              TEXT,
  ADD COLUMN IF NOT EXISTS microhabitat              TEXT,
  ADD COLUMN IF NOT EXISTS leaf_shape                TEXT,
  ADD COLUMN IF NOT EXISTS flower_color              TEXT,
  ADD COLUMN IF NOT EXISTS life_stage                TEXT,
  ADD COLUMN IF NOT EXISTS phenology                 TEXT,
  ADD COLUMN IF NOT EXISTS population_count          INTEGER,
  ADD COLUMN IF NOT EXISTS population_status         TEXT,
  ADD COLUMN IF NOT EXISTS threat_level              TEXT,
  ADD COLUMN IF NOT EXISTS threat_types              TEXT,
  ADD COLUMN IF NOT EXISTS institution               TEXT,
  ADD COLUMN IF NOT EXISTS team_members              JSONB,
  ADD COLUMN IF NOT EXISTS researcher_notes          TEXT,
  ADD COLUMN IF NOT EXISTS whole_plant_photo_path    TEXT,
  ADD COLUMN IF NOT EXISTS closeup_flower_photo_path TEXT,
  ADD COLUMN IF NOT EXISTS habitat_photo_path        TEXT,
  ADD COLUMN IF NOT EXISTS review_status             TEXT DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS review_notes              TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at               TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS local_names               TEXT,
  ADD COLUMN IF NOT EXISTS common_names              TEXT,
  ADD COLUMN IF NOT EXISTS endemic_to_philippines    BOOLEAN,
  ADD COLUMN IF NOT EXISTS identification_confidence TEXT,
  ADD COLUMN IF NOT EXISTS province                  TEXT,
  ADD COLUMN IF NOT EXISTS municipality              TEXT,
  ADD COLUMN IF NOT EXISTS specific_site             TEXT,
  ADD COLUMN IF NOT EXISTS growth_substrate          TEXT,
  ADD COLUMN IF NOT EXISTS host_tree_species         TEXT,
  ADD COLUMN IF NOT EXISTS host_tree_diameter        TEXT,
  ADD COLUMN IF NOT EXISTS canopy_cover              TEXT,
  ADD COLUMN IF NOT EXISTS light_exposure            TEXT,
  ADD COLUMN IF NOT EXISTS soil_type                 TEXT,
  ADD COLUMN IF NOT EXISTS nearby_water_source       TEXT,
  ADD COLUMN IF NOT EXISTS plant_height              TEXT,
  ADD COLUMN IF NOT EXISTS pseudobulb_present        TEXT,
  ADD COLUMN IF NOT EXISTS stem_length               TEXT,
  ADD COLUMN IF NOT EXISTS root_length               TEXT,
  ADD COLUMN IF NOT EXISTS leaf_length               TEXT,
  ADD COLUMN IF NOT EXISTS leaf_width                TEXT,
  ADD COLUMN IF NOT EXISTS leaf_texture              TEXT,
  ADD COLUMN IF NOT EXISTS leaf_arrangement          TEXT,
  ADD COLUMN IF NOT EXISTS number_of_leaves          TEXT,
  ADD COLUMN IF NOT EXISTS flowering_season          TEXT,
  ADD COLUMN IF NOT EXISTS number_of_flowers         TEXT,
  ADD COLUMN IF NOT EXISTS flower_diameter           TEXT,
  ADD COLUMN IF NOT EXISTS inflorescence_type        TEXT,
  ADD COLUMN IF NOT EXISTS petal_characteristics     TEXT,
  ADD COLUMN IF NOT EXISTS sepal_characteristics     TEXT,
  ADD COLUMN IF NOT EXISTS labellum_description      TEXT,
  ADD COLUMN IF NOT EXISTS fragrance                 TEXT,
  ADD COLUMN IF NOT EXISTS blooming_stage            TEXT,
  ADD COLUMN IF NOT EXISTS fruit_present             TEXT,
  ADD COLUMN IF NOT EXISTS fruit_type                TEXT,
  ADD COLUMN IF NOT EXISTS seed_capsule_condition    TEXT,
  ADD COLUMN IF NOT EXISTS ethnobotanical_importance TEXT,
  ADD COLUMN IF NOT EXISTS aesthetic_appeal          TEXT,
  ADD COLUMN IF NOT EXISTS cultivation               TEXT,
  ADD COLUMN IF NOT EXISTS rarity                    TEXT,
  ADD COLUMN IF NOT EXISTS cultural_importance       TEXT,
  ADD COLUMN IF NOT EXISTS unusual_observations      TEXT,
  ADD COLUMN IF NOT EXISTS study_title               TEXT,
  ADD COLUMN IF NOT EXISTS study_link                TEXT,
  ADD COLUMN IF NOT EXISTS updated_at                TIMESTAMPTZ DEFAULT NOW();


-- ============================================================
-- STEP 2: Clear existing seed data
-- ============================================================

DELETE FROM species_sightings WHERE entry_id LIKE 'BLOOM-%';

DELETE FROM biogeography
WHERE orchid_id IN (SELECT orchid_id FROM orchids WHERE sci_name IN (
  'Vanda sanderiana','Dendrobium secundum','Spathoglottis plicata',
  'Aerides quinquevulnera','Coelogyne asperata','Bulbophyllum lobbii',
  'Trichoglottis brachiata','Calanthe triplicata',
  'Paphiopedilum fowliei','Phalaenopsis schilleriana'
));

DELETE FROM picture WHERE file_path LIKE 'sightings/seed_%';

DELETE FROM orchids WHERE sci_name IN (
  'Vanda sanderiana','Dendrobium secundum','Spathoglottis plicata',
  'Aerides quinquevulnera','Coelogyne asperata','Bulbophyllum lobbii',
  'Trichoglottis brachiata','Calanthe triplicata',
  'Paphiopedilum fowliei','Phalaenopsis schilleriana'
);

DELETE FROM genus WHERE genus_name IN (
  'Vanda','Dendrobium','Spathoglottis','Aerides','Coelogyne',
  'Bulbophyllum','Trichoglottis','Calanthe','Paphiopedilum','Phalaenopsis'
);


-- ============================================================
-- STEP 3: Genus
-- ============================================================

INSERT INTO genus (genus_name) VALUES
  ('Vanda'),
  ('Dendrobium'),
  ('Spathoglottis'),
  ('Aerides'),
  ('Coelogyne'),
  ('Bulbophyllum'),
  ('Trichoglottis'),
  ('Calanthe'),
  ('Paphiopedilum'),
  ('Phalaenopsis')
ON CONFLICT (genus_name) DO NOTHING;


-- ============================================================
-- STEP 4: Orchid species (the catalog)
-- ============================================================

INSERT INTO orchids (sci_name, common_name, genus_id) VALUES
  ('Vanda sanderiana',          'Waling-waling',              (SELECT genus_id FROM genus WHERE genus_name = 'Vanda')),
  ('Dendrobium secundum',       'Toothbrush Orchid',          (SELECT genus_id FROM genus WHERE genus_name = 'Dendrobium')),
  ('Spathoglottis plicata',     'Philippine Ground Orchid',   (SELECT genus_id FROM genus WHERE genus_name = 'Spathoglottis')),
  ('Aerides quinquevulnera',    'Five-spotted Aerides',       (SELECT genus_id FROM genus WHERE genus_name = 'Aerides')),
  ('Coelogyne asperata',        'Rough Coelogyne',            (SELECT genus_id FROM genus WHERE genus_name = 'Coelogyne')),
  ('Bulbophyllum lobbii',       'Lobby''s Bulbophyllum',      (SELECT genus_id FROM genus WHERE genus_name = 'Bulbophyllum')),
  ('Trichoglottis brachiata',   'Philippine Trichoglottis',   (SELECT genus_id FROM genus WHERE genus_name = 'Trichoglottis')),
  ('Calanthe triplicata',       'White Calanthe',             (SELECT genus_id FROM genus WHERE genus_name = 'Calanthe')),
  ('Paphiopedilum fowliei',     'Fowlie''s Slipper Orchid',  (SELECT genus_id FROM genus WHERE genus_name = 'Paphiopedilum')),
  ('Phalaenopsis schilleriana', 'Schiller''s Moth Orchid',   (SELECT genus_id FROM genus WHERE genus_name = 'Phalaenopsis'))
ON CONFLICT (sci_name) DO UPDATE SET
  common_name = EXCLUDED.common_name,
  genus_id    = COALESCE(EXCLUDED.genus_id, orchids.genus_id);


-- ============================================================
-- STEP 5: Species sightings (1 per species = 10 total)
-- ============================================================

INSERT INTO species_sightings (
  entry_id, researcher_email, researcher_name,
  scientific_name, observation_date, observation_time,
  collection_method, observation_type, voucher_collected,
  mountain_name, specific_site_zone,
  latitude, longitude, elevation_meters,
  habitat_type, microhabitat,
  leaf_shape, flower_color, life_stage, phenology,
  population_count, population_status, threat_level, threat_types,
  institution, team_members, researcher_notes,
  whole_plant_photo_path, closeup_flower_photo_path, habitat_photo_path,
  review_status, created_at
) VALUES

('BLOOM-VS-001',
 'researcher1@msugensan.edu.ph', 'Dr. Maria Santos',
 'Vanda sanderiana', '2024-09-14', '08:30',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '900–1000 masl',
 6.0908, 124.7198, 945.0,
 'Montane forest', 'Epiphytic on Dipterocarp branches',
 'Strap-shaped', 'Pink-violet with brown markings', 'Mature flowering', 'In full bloom',
 8, 'Stable', 'Moderate', '["over-collection","habitat_loss"]'::jsonb,
 'MSU General Santos',
 '[{"name":"Juan dela Cruz","role":"Field Assistant"},{"name":"Ana Reyes","role":"Data Encoder"}]',
 'Observed 8 individuals on main trunk of large Dipterocarp at 945 m. All individuals healthy and in peak bloom.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_vanda_sanderiana.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_vanda.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_montane.jpg',
 'approved', '2024-09-15T06:00:00Z'),

('BLOOM-DS-001',
 'researcher1@msugensan.edu.ph', 'Dr. Maria Santos',
 'Dendrobium secundum', '2024-07-10', '10:00',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '800–900 masl',
 6.0914, 124.7192, 862.0,
 'Lower montane forest', 'Epiphytic on small branches near stream',
 'Linear', 'Pink', 'Mature flowering', 'Peak bloom',
 15, 'Stable', 'Low', '["habitat_loss"]'::jsonb,
 'MSU General Santos',
 '[{"name":"Ana Reyes","role":"Field Assistant"}]',
 'Dense toothbrush-like spike with ~30 small pink flowers. Found beside stream crossing.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_dendrobium_secundum.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_dendrobium.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_stream.jpg',
 'approved', '2024-07-11T06:00:00Z'),

('BLOOM-SP-001',
 'researcher1@msugensan.edu.ph', 'Dr. Maria Santos',
 'Spathoglottis plicata', '2024-06-05', '07:00',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '700–800 masl',
 6.0905, 124.7200, 755.0,
 'Trail edge grassland', 'Terrestrial in rocky soil',
 'Pleated', 'Purple', 'Mature flowering', 'Peak bloom',
 30, 'Abundant', 'Low', '["habitat_loss"]'::jsonb,
 'MSU General Santos',
 '[{"name":"Juan dela Cruz","role":"Field Assistant"}]',
 'Large terrestrial colony at trail entrance. Disturbed area from trail maintenance noted nearby.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_spathoglottis_plicata.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_spathoglottis.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_grassland.jpg',
 'approved', '2024-06-06T06:00:00Z'),

('BLOOM-AQ-001',
 'researcher1@msugensan.edu.ph', 'Dr. Maria Santos',
 'Aerides quinquevulnera', '2024-10-03', '10:30',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '950–1050 masl',
 6.0935, 124.7172, 998.0,
 'Montane forest interior', 'Epiphytic on upper canopy branches',
 'Strap-shaped', 'White with purple tips', 'Mature flowering', 'Late bloom',
 6, 'Rare', 'High', '["over-collection","climate_change"]'::jsonb,
 'MSU General Santos',
 '[{"name":"Ana Reyes","role":"Field Assistant"},{"name":"Juan dela Cruz","role":"Field Assistant"}]',
 'Small population of 6 individuals. Fragrant flowers attract pollinators. Population at risk from collectors.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_aerides_quinquevulnera.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_aerides.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_montane.jpg',
 'approved', '2024-10-04T06:00:00Z'),

('BLOOM-CA-001',
 'researcher2@msugensan.edu.ph', 'Prof. Jose Lim',
 'Coelogyne asperata', '2024-08-29', '09:00',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '1000–1100 masl',
 6.0943, 124.7165, 1050.0,
 'Mossy lower montane forest', 'Epiphytic on moss-covered boulders',
 'Oblong-elliptic', 'Cream-white with orange markings', 'Mature flowering', 'Peak bloom',
 14, 'Stable', 'Low', '["habitat_loss"]'::jsonb,
 'Notre Dame University',
 '[{"name":"Luz Navarro","role":"Field Assistant"},{"name":"Carlo Bautista","role":"Research Lead"}]',
 'Dense colony on large mossy boulders. Cream flowers with distinctive orange-brown disc. Excellent habitat.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_coelogyne_asperata.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_coelogyne.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_mossy.jpg',
 'approved', '2024-08-30T06:00:00Z'),

('BLOOM-BL-001',
 'researcher2@msugensan.edu.ph', 'Prof. Jose Lim',
 'Bulbophyllum lobbii', '2024-07-25', '11:00',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '900–1000 masl',
 6.0921, 124.7185, 952.0,
 'Montane forest', 'Epiphytic on mossy bark, lower canopy',
 'Oval-oblong', 'Yellow with red stripes', 'Mature flowering', 'Peak bloom',
 10, 'Stable', 'Low', '[]'::jsonb,
 'Notre Dame University',
 '[{"name":"Luz Navarro","role":"Field Assistant"}]',
 'Characteristic large solitary flower with swaying petals. Found on shaded mossy bark zone.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_bulbophyllum_lobbii.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_bulbophyllum.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_montane.jpg',
 'approved', '2024-07-26T06:00:00Z'),

('BLOOM-TB-001',
 'researcher3@msugensan.edu.ph', 'Dr. Carla Reyes',
 'Trichoglottis brachiata', '2024-09-07', '08:15',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '800–900 masl',
 6.0909, 124.7197, 845.0,
 'Forest edge', 'Epiphytic on forest edge trees',
 'Linear-oblong', 'Dark maroon with white lip', 'Mature flowering', 'Full bloom',
 9, 'Stable', 'Moderate', '["habitat_loss","over-collection"]'::jsonb,
 'DOST-PCAARRD',
 '[{"name":"Mark Torres","role":"Field Assistant"}]',
 'Characteristic dark maroon flowers. Plants found on sun-exposed branches at forest edge.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_trichoglottis_brachiata.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_trichoglottis.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_forest_edge.jpg',
 'approved', '2024-09-08T06:00:00Z'),

('BLOOM-CT-001',
 'researcher3@msugensan.edu.ph', 'Dr. Carla Reyes',
 'Calanthe triplicata', '2024-06-18', '09:30',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '850–950 masl',
 6.0912, 124.7194, 898.0,
 'Forest floor near stream', 'Terrestrial in humus-rich soil near water',
 'Pleated', 'White', 'Mature flowering', 'Peak bloom',
 22, 'Stable', 'Low', '["habitat_loss"]'::jsonb,
 'DOST-PCAARRD',
 '[{"name":"Jay Cruz","role":"Photographer"},{"name":"Mark Torres","role":"Field Assistant"}]',
 'Pure white flower spikes emerging from large pleated leaves. Dense stand near seasonal stream.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_calanthe_triplicata.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_calanthe.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_stream.jpg',
 'approved', '2024-06-19T06:00:00Z'),

('BLOOM-PF-001',
 'researcher1@msugensan.edu.ph', 'Dr. Maria Santos',
 'Paphiopedilum fowliei', '2024-10-20', '09:00',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '1000–1100 masl',
 6.0950, 124.7157, 1058.0,
 'Limestone forest', 'Terrestrial on limestone outcrops with humus pockets',
 'Linear-lanceolate', 'Purple-veined white', 'Mature flowering', 'Peak bloom',
 4, 'Critically Rare', 'Very High', '["over-collection","habitat_loss","climate_change"]'::jsonb,
 'MSU General Santos',
 '[{"name":"Ana Reyes","role":"Field Assistant"},{"name":"Pedro Gomez","role":"Field Assistant"}]',
 'CRITICAL: Only 4 reproductive adults found. Mindanao endemic highly threatened. Coordinates marked for long-term monitoring.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_paphiopedilum_fowliei.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_paphiopedilum.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_limestone.jpg',
 'approved', '2024-10-21T06:00:00Z'),

('BLOOM-PSC-001',
 'researcher3@msugensan.edu.ph', 'Dr. Carla Reyes',
 'Phalaenopsis schilleriana', '2024-09-25', '11:00',
 'Visual', 'In-situ', FALSE,
 'Mt. Busa', '900–1000 masl',
 6.0922, 124.7183, 952.0,
 'Lower montane forest', 'Epiphytic on large shaded tree trunks',
 'Elliptic-oblong', 'Pink-lavender', 'Mature flowering', 'Late bloom',
 7, 'Declining', 'High', '["over-collection","habitat_loss"]'::jsonb,
 'DOST-PCAARRD',
 '[{"name":"Jay Cruz","role":"Photographer"}]',
 'Silver-mottled leaves and pink flowers. Once common but now rare due to sustained collection pressure.',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_phalaenopsis_schilleriana.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_closeup_phalaenopsis.jpg',
 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/sightings/seed_habitat_montane.jpg',
 'approved', '2024-09-26T06:00:00Z');


-- ============================================================
-- STEP 6: Fill in all extended sighting fields per species
-- ============================================================

UPDATE species_sightings SET
  local_names               = '["Waling-waling","Waling-waling na pula"]',
  common_names              = '["Waling-waling Orchid","Queen of Philippine Flowers"]',
  endemic_to_philippines    = TRUE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Epiphytic',
  host_tree_species         = 'Dipterocarpus sp.',
  canopy_cover              = 'Dense (>75%)',
  light_exposure            = 'Partial shade',
  plant_height              = '30–60 cm',
  pseudobulb_present        = 'No',
  leaf_length               = '25–35 cm',
  leaf_width                = '3–4 cm',
  leaf_texture              = 'Leathery',
  leaf_arrangement          = 'Distichous',
  number_of_leaves          = '8–14',
  flowering_season          = 'August–November',
  number_of_flowers         = '7–15 per raceme',
  flower_diameter           = '8–10 cm',
  inflorescence_type        = 'Raceme',
  petal_characteristics     = 'Broad, rounded, pink-violet with brown reticulations',
  sepal_characteristics     = 'Dorsal sepal erect; lateral sepals spreading',
  labellum_description      = 'Three-lobed, white with purple streaks',
  fragrance                 = 'Mild, sweet',
  blooming_stage            = 'Full bloom',
  fruit_present             = 'No',
  ethnobotanical_importance = 'National symbol; used in ornamental horticulture',
  aesthetic_appeal          = 'Very High',
  cultivation               = 'Suitable for intermediate to warm conditions',
  rarity                    = 'Critically Rare',
  cultural_importance       = 'National icon; central to Davao orchid festivals'
WHERE scientific_name = 'Vanda sanderiana';

UPDATE species_sightings SET
  local_names               = '["Palaypalayan","Suklay-suklay"]',
  common_names              = '["Toothbrush Orchid","Pink Bottlebrush Orchid"]',
  endemic_to_philippines    = FALSE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Epiphytic',
  plant_height              = '20–50 cm',
  pseudobulb_present        = 'Yes',
  leaf_length               = '8–12 cm',
  leaf_texture              = 'Leathery',
  flowering_season          = 'January–April',
  number_of_flowers         = '30–50 per raceme (dense)',
  inflorescence_type        = 'Dense lateral raceme (toothbrush-like)',
  fragrance                 = 'None',
  ethnobotanical_importance = 'Ornamental use; occasionally used in garlands',
  aesthetic_appeal          = 'High',
  rarity                    = 'Uncommon'
WHERE scientific_name = 'Dendrobium secundum';

UPDATE species_sightings SET
  local_names               = '["Lupa-lupa","Kolokoy"]',
  common_names              = '["Philippine Ground Orchid","Pleated Leaf Orchid"]',
  endemic_to_philippines    = FALSE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Terrestrial',
  soil_type                 = 'Rocky humus-rich soil',
  plant_height              = '40–80 cm',
  pseudobulb_present        = 'Yes',
  leaf_length               = '30–60 cm',
  leaf_texture              = 'Pleated, membranous',
  flowering_season          = 'Year-round',
  inflorescence_type        = 'Terminal raceme',
  fragrance                 = 'Faint',
  ethnobotanical_importance = 'Common ornamental; used in roadside planting',
  aesthetic_appeal          = 'High',
  rarity                    = 'Common'
WHERE scientific_name = 'Spathoglottis plicata';

UPDATE species_sightings SET
  local_names               = '["Sinampaga","Sampaguita Orchid"]',
  common_names              = '["Five-spotted Aerides","Fox-tail Orchid"]',
  endemic_to_philippines    = TRUE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Epiphytic',
  plant_height              = '30–50 cm',
  inflorescence_type        = 'Pendant raceme',
  fragrance                 = 'Strong, sweet-spicy',
  ethnobotanical_importance = 'Prized as cut flower; traded ornamental',
  aesthetic_appeal          = 'Very High',
  rarity                    = 'Rare',
  cultural_importance       = 'Worn as adornment in traditional Moro ceremonies'
WHERE scientific_name = 'Aerides quinquevulnera';

UPDATE species_sightings SET
  local_names               = '["Mutyang-bundok"]',
  common_names              = '["Rough Coelogyne","Necklace Orchid"]',
  endemic_to_philippines    = FALSE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Epiphytic / Lithophytic',
  plant_height              = '25–45 cm',
  inflorescence_type        = 'Erect raceme from pseudobulb apex',
  fragrance                 = 'Light, pleasant',
  ethnobotanical_importance = 'Ornamental; collected for home gardens',
  aesthetic_appeal          = 'High',
  rarity                    = 'Uncommon'
WHERE scientific_name = 'Coelogyne asperata';

UPDATE species_sightings SET
  local_names               = '["Tayabak","Kulitkulit"]',
  common_names              = '["Lobby''s Bulbophyllum"]',
  endemic_to_philippines    = FALSE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Epiphytic',
  plant_height              = '10–20 cm',
  inflorescence_type        = 'Single-flowered scape',
  fragrance                 = 'Faint, musty',
  ethnobotanical_importance = 'Specialist orchid collector interest',
  aesthetic_appeal          = 'Moderate',
  rarity                    = 'Uncommon'
WHERE scientific_name = 'Bulbophyllum lobbii';

UPDATE species_sightings SET
  local_names               = '["Taling-taling","Taling ng gubat"]',
  common_names              = '["Philippine Trichoglottis","Braided Orchid"]',
  endemic_to_philippines    = TRUE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Epiphytic',
  plant_height              = '20–40 cm',
  inflorescence_type        = 'Short axillary clusters',
  fragrance                 = 'None',
  ethnobotanical_importance = 'Ornamental; rare in cultivation',
  aesthetic_appeal          = 'High',
  rarity                    = 'Rare'
WHERE scientific_name = 'Trichoglottis brachiata';

UPDATE species_sightings SET
  local_names               = '["Kutog","Bulaklak-bundok"]',
  common_names              = '["White Calanthe","Christmas Orchid"]',
  endemic_to_philippines    = FALSE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Terrestrial',
  soil_type                 = 'Humus-rich forest floor',
  plant_height              = '50–90 cm',
  inflorescence_type        = 'Erect terminal raceme',
  fragrance                 = 'Mild, sweet',
  ethnobotanical_importance = 'Used medicinally for skin ailments in some indigenous communities',
  aesthetic_appeal          = 'High',
  rarity                    = 'Uncommon',
  cultural_importance       = 'Used as offering flowers in some Lumad communities'
WHERE scientific_name = 'Calanthe triplicata';

UPDATE species_sightings SET
  local_names               = '["Zapatilya","Dapa-dapa"]',
  common_names              = '["Fowlie''s Slipper Orchid","Mindanao Lady Slipper"]',
  endemic_to_philippines    = TRUE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Terrestrial / Lithophytic',
  soil_type                 = 'Limestone humus pockets',
  plant_height              = '15–25 cm',
  inflorescence_type        = 'Single-flowered scape',
  fragrance                 = 'None',
  ethnobotanical_importance = 'CITES Appendix I; strictly protected; no legal trade',
  aesthetic_appeal          = 'Very High',
  rarity                    = 'Critically Rare',
  cultural_importance       = 'Sacred to local Lumad communities as sign of pure forest'
WHERE scientific_name = 'Paphiopedilum fowliei';

UPDATE species_sightings SET
  local_names               = '["Mariposa","Paruparo"]',
  common_names              = '["Schiller''s Moth Orchid","Pink Moth Orchid"]',
  endemic_to_philippines    = TRUE,
  identification_confidence = 'Confirmed',
  province                  = 'South Cotabato',
  municipality              = 'Polomolok',
  growth_substrate          = 'Epiphytic',
  plant_height              = '20–40 cm',
  inflorescence_type        = 'Branched panicle',
  fragrance                 = 'Light, sweet',
  ethnobotanical_importance = 'Highly prized ornamental; sold at orchid markets',
  aesthetic_appeal          = 'Very High',
  rarity                    = 'Rare',
  cultural_importance       = 'Featured in Philippine postage stamps and cultural events'
WHERE scientific_name = 'Phalaenopsis schilleriana';


-- ============================================================
-- STEP 7: Catalog hero images
-- ============================================================

INSERT INTO picture (file_path, file_type) VALUES
  ('sightings/seed_vanda_sanderiana.jpg',          'image/jpeg'),
  ('sightings/seed_dendrobium_secundum.jpg',        'image/jpeg'),
  ('sightings/seed_spathoglottis_plicata.jpg',      'image/jpeg'),
  ('sightings/seed_aerides_quinquevulnera.jpg',     'image/jpeg'),
  ('sightings/seed_coelogyne_asperata.jpg',         'image/jpeg'),
  ('sightings/seed_bulbophyllum_lobbii.jpg',        'image/jpeg'),
  ('sightings/seed_trichoglottis_brachiata.jpg',    'image/jpeg'),
  ('sightings/seed_calanthe_triplicata.jpg',        'image/jpeg'),
  ('sightings/seed_paphiopedilum_fowliei.jpg',      'image/jpeg'),
  ('sightings/seed_phalaenopsis_schilleriana.jpg',  'image/jpeg')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'picture' AND column_name = 'status'
  ) THEN
    EXECUTE 'UPDATE picture SET status = ''approved'' WHERE file_path LIKE ''sightings/seed_%'' AND (status IS NULL OR status <> ''approved'')';
  END IF;
END $$;

UPDATE picture
SET file_url = CASE
  WHEN file_path LIKE 'http%' THEN file_path
  ELSE 'https://fmvkxvmrycsubjmkyaet.supabase.co/storage/v1/object/public/bloom-uploads/' || file_path
END
WHERE file_path LIKE 'sightings/seed_%'
  AND (file_url IS NULL OR file_url = '');

UPDATE picture p
SET orchid_id = o.orchid_id
FROM orchids o
WHERE p.file_path = (
  'sightings/seed_' ||
  lower(replace(replace(o.sci_name, ' ', '_'), '''', '')) ||
  '.jpg'
)
  AND (p.orchid_id IS NULL OR p.orchid_id = 0);

INSERT INTO biogeography (orchid_id, picture_id, submission_status)
SELECT o.orchid_id, p.picture_id, 'approved'
FROM orchids o
JOIN picture p ON p.file_path = (
  'sightings/seed_' ||
  lower(replace(replace(o.sci_name, ' ', '_'), '''', '')) ||
  '.jpg'
)
ON CONFLICT DO NOTHING;


-- ============================================================
-- Verification — should show 10 genus, 10 orchids, 10 sightings,
--                             10 seed pictures, 10 biogeography rows
-- ============================================================
SELECT 'genus'            AS table_name, COUNT(*) AS rows FROM genus
UNION ALL
SELECT 'orchids',                        COUNT(*) FROM orchids
UNION ALL
SELECT 'species_sightings',              COUNT(*) FROM species_sightings
UNION ALL
SELECT 'picture (seed)',                 COUNT(*) FROM picture WHERE file_path LIKE 'sightings/seed_%'
UNION ALL
SELECT 'biogeography',                   COUNT(*) FROM biogeography;
