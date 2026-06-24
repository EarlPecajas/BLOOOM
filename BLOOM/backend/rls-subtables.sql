-- ── RLS policies for 3NF sub-tables ─────────────────────────────────────
-- The sub-tables created by 3nf-migration.sql have RLS enabled by default
-- but no policies, which blocks all client-side access.
-- These policies match the permissive pattern used on species_sightings.

-- sighting_habitat
ALTER TABLE sighting_habitat ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_sighting_habitat" ON sighting_habitat;
CREATE POLICY "allow_all_sighting_habitat" ON sighting_habitat
  FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- sighting_morphology
ALTER TABLE sighting_morphology ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_sighting_morphology" ON sighting_morphology;
CREATE POLICY "allow_all_sighting_morphology" ON sighting_morphology
  FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- sighting_conservation
ALTER TABLE sighting_conservation ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_sighting_conservation" ON sighting_conservation;
CREATE POLICY "allow_all_sighting_conservation" ON sighting_conservation
  FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- sighting_team_member
ALTER TABLE sighting_team_member ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_sighting_team_member" ON sighting_team_member;
CREATE POLICY "allow_all_sighting_team_member" ON sighting_team_member
  FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- sighting_media
ALTER TABLE sighting_media ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_sighting_media" ON sighting_media;
CREATE POLICY "allow_all_sighting_media" ON sighting_media
  FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- picture
ALTER TABLE picture ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_all_picture" ON picture;
CREATE POLICY "allow_all_picture" ON picture
  FOR ALL TO anon, authenticated
  USING (true) WITH CHECK (true);

-- mountain (needed for the mountain_id lookup on submit)
ALTER TABLE mountain ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_select_mountain" ON mountain;
CREATE POLICY "allow_select_mountain" ON mountain
  FOR SELECT TO anon, authenticated
  USING (true);
