-- Upgrades catalog_edit_requests (see add-catalog-edit-requests-table.sql,
-- must be run first) from a free-text "reason" request into a full
-- field-level edit proposal: the researcher's pre-filled edit form submits
-- the actual new values, so DENR can review an old-vs-new diff and, on
-- approval, apply the change directly to species_sightings without a
-- round-trip through the revision flow.
--
-- proposed_changes is a JSONB object of { column_name: new_value }, limited
-- at the application layer to a safe whitelist of editable columns.
-- reason becomes optional — the researcher can still add context, but it's
-- no longer the only thing DENR sees.
--
-- Safe to re-run. Run this in the Supabase SQL Editor.

BEGIN;

ALTER TABLE catalog_edit_requests
  ADD COLUMN IF NOT EXISTS proposed_changes JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE catalog_edit_requests
  ALTER COLUMN reason DROP NOT NULL;

COMMIT;
