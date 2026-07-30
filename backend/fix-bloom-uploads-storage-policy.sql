-- "Failed to publish: Thumbnail upload failed: new row violates row-level
-- security policy" — the intended INSERT policy for the bloom-uploads bucket
-- (see supabase-only.sql) is wrapped in a DO block that silently swallows
-- insufficient_privilege errors, so it may never have actually been created.
-- Run this directly (no exception-swallowing) so any failure here is visible.

INSERT INTO storage.buckets (id, name, public)
VALUES ('bloom-uploads', 'bloom-uploads', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Not ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY here — that table
-- is owned by a Supabase-internal role, not the postgres role the SQL Editor
-- runs as, so that statement always fails with "must be owner of table
-- objects". RLS is already enabled on it by Supabase's own setup; only the
-- policies below need to exist, and creating policies doesn't require
-- ownership.

DROP POLICY IF EXISTS "Public read bloom uploads" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload bloom files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update bloom files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated delete bloom files" ON storage.objects;

CREATE POLICY "Public read bloom uploads"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'bloom-uploads');

CREATE POLICY "Authenticated upload bloom files"
  ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'bloom-uploads' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated update bloom files"
  ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'bloom-uploads' AND auth.role() = 'authenticated')
  WITH CHECK (bucket_id = 'bloom-uploads' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated delete bloom files"
  ON storage.objects
  FOR DELETE
  USING (bucket_id = 'bloom-uploads' AND auth.role() = 'authenticated');
