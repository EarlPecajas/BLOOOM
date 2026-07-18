BEGIN;

-- Soft-delete flag so DENR can archive a trail without losing its data,
-- plus an updated_at so edits are auditable.
ALTER TABLE map_trails ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE map_trails ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

GRANT UPDATE ON map_trails TO authenticated;

DROP POLICY IF EXISTS "Authenticated update map_trails" ON map_trails;

CREATE POLICY "Authenticated update map_trails"
  ON map_trails
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

COMMIT;
