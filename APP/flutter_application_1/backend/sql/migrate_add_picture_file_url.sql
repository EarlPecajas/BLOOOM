-- ============================================================
-- BLOOM3D Migration: add picture.file_url for catalog queries
-- Run once in Supabase SQL Editor or psql against the live DB.
-- Safe to re-run: uses ADD COLUMN IF NOT EXISTS.
-- ============================================================

ALTER TABLE picture
  ADD COLUMN IF NOT EXISTS file_url TEXT;

-- Backfill from file_path when present (Supabase datasets often use file_path).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'picture'
      AND column_name = 'file_path'
  ) THEN
    EXECUTE 'UPDATE picture SET file_url = file_path WHERE (file_url IS NULL OR file_url = '''') AND file_path IS NOT NULL';
  END IF;
END $$;

SELECT 'Migration complete — file_url column ready.' AS status;
