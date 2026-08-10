-- Lets a researcher ask DENR to edit one of their own already-submitted
-- (possibly already-published) sightings, without silently unpublishing it
-- just because a request was filed. DENR reviews these in a new dashboard
-- tab and approves or denies each one.
--
-- On approval, DENR flips the target species_sightings row's review_status
-- to 'revision' (reusing the existing pre-publish revision mechanism) so the
-- researcher can resubmit it through the normal resubmit flow.
--
-- Safe to re-run. Run this in the Supabase SQL Editor.

BEGIN;

CREATE TABLE IF NOT EXISTS catalog_edit_requests (
  id                SERIAL PRIMARY KEY,
  sighting_id       INTEGER NOT NULL REFERENCES species_sightings(sighting_id) ON DELETE CASCADE,
  researcher_email  VARCHAR(255) NOT NULL,
  reason            TEXT NOT NULL,
  status            VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (lower(status) IN ('pending', 'approved', 'denied')),
  denr_response     TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at       TIMESTAMPTZ,
  resolved_by       VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_catalog_edit_requests_sighting_id ON catalog_edit_requests(sighting_id);
CREATE INDEX IF NOT EXISTS idx_catalog_edit_requests_status ON catalog_edit_requests(status);

ALTER TABLE catalog_edit_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Researcher insert own edit requests" ON catalog_edit_requests;
CREATE POLICY "Researcher insert own edit requests"
  ON catalog_edit_requests FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND researcher_email = auth.jwt()->>'email');

DROP POLICY IF EXISTS "Researcher read own edit requests" ON catalog_edit_requests;
CREATE POLICY "Researcher read own edit requests"
  ON catalog_edit_requests FOR SELECT
  USING (
    researcher_email = auth.jwt()->>'email'
    OR EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND lower(up.role) IN ('admin','denr'))
  );

DROP POLICY IF EXISTS "DENR update edit requests" ON catalog_edit_requests;
CREATE POLICY "DENR update edit requests"
  ON catalog_edit_requests FOR UPDATE
  USING (EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND lower(up.role) IN ('admin','denr')))
  WITH CHECK (EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = auth.uid() AND lower(up.role) IN ('admin','denr')));

COMMIT;
