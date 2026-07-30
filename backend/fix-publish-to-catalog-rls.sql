-- "Failed to publish: new row violates row-level security policy for table
-- orchids" — same root cause as fix-bloom-uploads-storage-policy.sql: the
-- INSERT/UPDATE policies documented for these tables in earlier migrations
-- (supabase-only.sql, add-model-3d-to-orchids.sql) either never actually
-- landed on this database or were dropped since. Rather than fix one table
-- at a time as each next RLS error surfaces, this covers every table the
-- Publish to Catalog flow (submitPostToCatalog in denr-dashboard.html)
-- writes to: orchids, picture, conservation_status, biogeography, and
-- species_sightings.

GRANT SELECT, INSERT, UPDATE ON orchids            TO authenticated;
GRANT SELECT, INSERT, UPDATE ON picture             TO authenticated;
GRANT SELECT, INSERT, UPDATE ON conservation_status TO authenticated;
GRANT SELECT, INSERT, UPDATE ON biogeography        TO authenticated;
GRANT SELECT, INSERT, UPDATE ON species_sightings   TO authenticated;

DO $$
BEGIN
  EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated';
EXCEPTION
  WHEN undefined_table THEN NULL;
END $$;

-- orchids
DROP POLICY IF EXISTS "Public read orchids" ON orchids;
DROP POLICY IF EXISTS "Authenticated insert orchids" ON orchids;
DROP POLICY IF EXISTS "Authenticated update orchids" ON orchids;

CREATE POLICY "Public read orchids"
  ON orchids FOR SELECT USING (true);
CREATE POLICY "Authenticated insert orchids"
  ON orchids FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated update orchids"
  ON orchids FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- picture
DROP POLICY IF EXISTS "Public read picture" ON picture;
DROP POLICY IF EXISTS "Authenticated read picture" ON picture;
DROP POLICY IF EXISTS "Authenticated insert picture" ON picture;
DROP POLICY IF EXISTS "Authenticated update picture" ON picture;

CREATE POLICY "Public read picture"
  ON picture FOR SELECT USING (true);
CREATE POLICY "Authenticated insert picture"
  ON picture FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated update picture"
  ON picture FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- conservation_status
DROP POLICY IF EXISTS "Public read conservation_status" ON conservation_status;
DROP POLICY IF EXISTS "Authenticated insert conservation_status" ON conservation_status;

CREATE POLICY "Public read conservation_status"
  ON conservation_status FOR SELECT USING (true);
CREATE POLICY "Authenticated insert conservation_status"
  ON conservation_status FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- biogeography
DROP POLICY IF EXISTS "Public read biogeography" ON biogeography;
DROP POLICY IF EXISTS "Authenticated insert biogeography" ON biogeography;
DROP POLICY IF EXISTS "Authenticated update biogeography" ON biogeography;

CREATE POLICY "Public read biogeography"
  ON biogeography FOR SELECT USING (true);
CREATE POLICY "Authenticated insert biogeography"
  ON biogeography FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated update biogeography"
  ON biogeography FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- species_sightings (already used successfully elsewhere for review-status
-- updates, but included defensively since this exact publish path failed)
DROP POLICY IF EXISTS "Authenticated update sightings" ON species_sightings;

CREATE POLICY "Authenticated update sightings"
  ON species_sightings FOR UPDATE USING (auth.role() = 'authenticated');
