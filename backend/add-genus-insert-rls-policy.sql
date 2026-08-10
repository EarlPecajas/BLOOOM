-- genus has RLS enabled with only a public SELECT policy, so DENR could
-- never actually create a new genus row from the client (e.g. Publish to
-- Catalog picking a DAO 2026-20 genus that has no genus row yet, after the
-- Genus dropdown was extended to list all 30 DAO 2026-20 genera regardless
-- of whether they already exist in this table). Matches the pattern
-- already used on orchids (INSERT/UPDATE gated to
-- auth.role() = 'authenticated').
--
-- Already applied directly to the live database. Kept here for reference
-- and reproducibility. Safe to re-run (will error harmlessly if the policy
-- already exists — drop it first if you need to re-create it).

BEGIN;

CREATE POLICY "Authenticated insert genus" ON genus
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

COMMIT;
