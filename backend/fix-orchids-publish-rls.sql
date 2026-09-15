-- Run this in Supabase → SQL Editor if "Publish to Catalog" fails with
-- "new row violates row-level security policy for table orchids" (or the
-- same error on biogeography/picture/conservation_status).
--
-- Idempotent — safe to run even if some/all of this already exists.
-- Mirrors the policies defined in backend/supabase-only.sql.

GRANT SELECT ON orchids TO anon, authenticated;
GRANT UPDATE ON orchids TO authenticated;
GRANT SELECT ON biogeography TO anon, authenticated;
GRANT SELECT ON conservation_status TO anon, authenticated;

ALTER TABLE orchids ENABLE ROW LEVEL SECURITY;
ALTER TABLE biogeography ENABLE ROW LEVEL SECURITY;
ALTER TABLE conservation_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE picture ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read orchids" ON orchids;
DROP POLICY IF EXISTS "Authenticated insert orchids" ON orchids;
DROP POLICY IF EXISTS "Authenticated update orchids" ON orchids;
DROP POLICY IF EXISTS "Public read biogeography" ON biogeography;
DROP POLICY IF EXISTS "Authenticated insert biogeography" ON biogeography;
DROP POLICY IF EXISTS "Authenticated update biogeography" ON biogeography;
DROP POLICY IF EXISTS "Public read conservation_status" ON conservation_status;
DROP POLICY IF EXISTS "Authenticated insert conservation_status" ON conservation_status;
DROP POLICY IF EXISTS "Authenticated read picture" ON picture;
DROP POLICY IF EXISTS "Authenticated insert picture" ON picture;
DROP POLICY IF EXISTS "Authenticated update picture" ON picture;

CREATE POLICY "Public read orchids"
  ON orchids FOR SELECT
  USING (true);

CREATE POLICY "Authenticated insert orchids"
  ON orchids FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated update orchids"
  ON orchids FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Public read biogeography"
  ON biogeography FOR SELECT
  USING (true);

CREATE POLICY "Authenticated insert biogeography"
  ON biogeography FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated update biogeography"
  ON biogeography FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Public read conservation_status"
  ON conservation_status FOR SELECT
  USING (true);

CREATE POLICY "Authenticated insert conservation_status"
  ON conservation_status FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated read picture"
  ON picture FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated insert picture"
  ON picture FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated update picture"
  ON picture FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
