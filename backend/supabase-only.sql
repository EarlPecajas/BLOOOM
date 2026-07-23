BEGIN;

-- Public catalog view for frontend-only Supabase access.
DROP VIEW IF EXISTS orchid_overview CASCADE;

CREATE OR REPLACE VIEW orchid_overview AS
SELECT
  o.orchid_id AS id,
  o.sci_name AS name,
  g.genus_name AS genus,
  coalesce(o.common_name, '')::text AS common_name,
  coalesce(o.endemicity, '')::text AS endemicity,
  NULL::text AS ethnobotanical,
  NULL::text AS horticulture_value,
  NULL::text AS cultural_importance,
  ''::text AS image_url,
  CASE
    WHEN lower(coalesce(cs.conservation_status, '')) IN ('critically endangered', 'critically_endangered') THEN 'critically_endangered'
    WHEN lower(coalesce(cs.conservation_status, '')) = 'endangered' THEN 'endangered'
    WHEN lower(coalesce(cs.conservation_status, '')) = 'vulnerable' THEN 'vulnerable'
    WHEN lower(coalesce(cs.conservation_status, '')) IN ('least concern', 'least_concern') THEN 'least_concern'
    ELSE 'unassigned'
  END AS conservation_status_key,
  coalesce(cs.conservation_status, 'Unassigned')::text AS conservation_status
FROM orchids o
INNER JOIN genus g ON g.genus_id = o.genus_id
LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
LEFT JOIN conservation_status cs ON cs.conservation_id = b.conservation_id;

DROP VIEW IF EXISTS public_approved_sightings;

CREATE OR REPLACE VIEW public_approved_sightings AS
SELECT
  s.sighting_id AS id,
  s.scientific_name,
  s.genus,
  s.common_names,
  s.local_names,
  s.identification_confidence,
  s.observation_type,
  s.observation_date,
  to_char(s.observation_date, 'YYYY-MM') AS observation_month,
  s.mountain_name,
  s.specific_site_zone,
  s.elevation_meters,
  s.habitat_type,
  s.microhabitat,
  s.plant_height_cm,
  s.leaf_shape,
  s.leaf_count,
  s.leaf_textures,
  s.leaf_arrangement,
  s.flower_color,
  s.flower_count,
  s.flower_diameter_cm,
  s.inflorescence_type,
  s.petal_characteristics,
  s.labellum_lip_description,
  s.fragrance,
  s.flowering_season,
  s.blooming_stage,
  s.fruit_present,
  s.fruit_type,
  s.population_status,
  CASE
    WHEN lower(coalesce(s.threat_level, '')) IN ('critically endangered', 'endangered', 'vulnerable', 'threatened') THEN 'Threatened'
    WHEN lower(coalesce(s.threat_level, '')) <> '' THEN 'Threatened'
    ELSE ''
  END AS threat_level_generalized,
  s.growth_substrate,
  s.nearby_water_source,
  NULL::text AS educational_notes,
  'Location hidden for conservation'::text AS location_visibility_note,
  s.researcher_name,
  s.team_members,
  s.institution,
  s.whole_plant_photo_path,
  s.closeup_flower_photo_path,
  s.habitat_photo_path
FROM species_sightings s
WHERE lower(coalesce(s.review_status, '')) = 'approved';

GRANT SELECT ON orchid_overview TO anon, authenticated;
GRANT SELECT ON public_approved_sightings TO anon, authenticated;
GRANT SELECT ON orchids TO anon, authenticated;
GRANT UPDATE ON orchids TO authenticated;
GRANT SELECT ON genus TO anon, authenticated;
GRANT SELECT ON biogeography TO anon, authenticated;
GRANT SELECT ON conservation_status TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON species_sightings TO authenticated;

DO $$
BEGIN
  EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated';
EXCEPTION
  WHEN undefined_table THEN
    NULL;
END $$;

ALTER TABLE orchids ENABLE ROW LEVEL SECURITY;
ALTER TABLE genus ENABLE ROW LEVEL SECURITY;
ALTER TABLE biogeography ENABLE ROW LEVEL SECURITY;
ALTER TABLE conservation_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE species_sightings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read orchids" ON orchids;
DROP POLICY IF EXISTS "Authenticated insert orchids" ON orchids;
DROP POLICY IF EXISTS "Authenticated update orchids" ON orchids;
DROP POLICY IF EXISTS "Public read genus" ON genus;
DROP POLICY IF EXISTS "Public read biogeography" ON biogeography;
DROP POLICY IF EXISTS "Authenticated insert biogeography" ON biogeography;
DROP POLICY IF EXISTS "Public read conservation_status" ON conservation_status;
DROP POLICY IF EXISTS "Authenticated read picture" ON picture;
DROP POLICY IF EXISTS "Authenticated insert picture" ON picture;
DROP POLICY IF EXISTS "Authenticated read sightings" ON species_sightings;
DROP POLICY IF EXISTS "Authenticated insert sightings" ON species_sightings;
DROP POLICY IF EXISTS "Authenticated update sightings" ON species_sightings;
DROP POLICY IF EXISTS "Authenticated delete sightings" ON species_sightings;

CREATE POLICY "Public read orchids"
  ON orchids
  FOR SELECT
  USING (true);

CREATE POLICY "Authenticated insert orchids"
  ON orchids
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated update orchids"
  ON orchids
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Public read genus"
  ON genus
  FOR SELECT
  USING (true);

CREATE POLICY "Public read biogeography"
  ON biogeography
  FOR SELECT
  USING (true);

CREATE POLICY "Authenticated insert biogeography"
  ON biogeography
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Public read conservation_status"
  ON conservation_status
  FOR SELECT
  USING (true);

CREATE POLICY "Authenticated read picture"
  ON picture
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated insert picture"
  ON picture
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated read sightings"
  ON species_sightings
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated insert sightings"
  ON species_sightings
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated update sightings"
  ON species_sightings
  FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated delete sightings"
  ON species_sightings
  FOR DELETE
  USING (auth.role() = 'authenticated');

DO $bootstrap$
BEGIN
  BEGIN
    EXECUTE 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping storage.objects RLS because the current role is not the table owner.';
  END;

  BEGIN
    EXECUTE 'DROP POLICY IF EXISTS "Public read bloom uploads" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "Authenticated upload bloom files" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "Authenticated delete bloom files" ON storage.objects';

    EXECUTE 'CREATE POLICY "Public read bloom uploads"
      ON storage.objects
      FOR SELECT
      USING (bucket_id = ''bloom-uploads'')';

    EXECUTE 'CREATE POLICY "Authenticated upload bloom files"
      ON storage.objects
      FOR INSERT
      WITH CHECK (bucket_id = ''bloom-uploads'' AND auth.role() = ''authenticated'')';

    EXECUTE 'CREATE POLICY "Authenticated delete bloom files"
      ON storage.objects
      FOR DELETE
      USING (bucket_id = ''bloom-uploads'' AND auth.role() = ''authenticated'')';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping storage.objects policy setup because the current role is not the table owner.';
  END;
END $bootstrap$;

DO $bucket$
BEGIN
  EXECUTE 'INSERT INTO storage.buckets (id, name, public)
    VALUES (''bloom-uploads'', ''bloom-uploads'', true)
    ON CONFLICT (id) DO UPDATE
    SET public = EXCLUDED.public,
        name = EXCLUDED.name';
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'Skipping storage.buckets upsert because the current role is not allowed to modify storage metadata.';
END $bucket$;

COMMIT;
