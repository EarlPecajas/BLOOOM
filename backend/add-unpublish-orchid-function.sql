BEGIN;

-- DENR's "Unpublish from Catalog" button calls this via bloomSupabase.rpc().
-- There is no DELETE policy on orchids/biogeography (only SELECT/INSERT/UPDATE),
-- so a direct client-side .delete() is silently blocked by RLS — this
-- SECURITY DEFINER function runs with elevated privileges to actually remove
-- the row on the authenticated user's behalf.
CREATE OR REPLACE FUNCTION public.unpublish_orchid(p_sci_name TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- biogeography.orchid_id -> orchids ON DELETE CASCADE already covers this,
  -- but stated explicitly in case that constraint is missing on a given
  -- environment (this project's migrations have not always landed cleanly).
  DELETE FROM biogeography
  WHERE orchid_id IN (
    SELECT orchid_id FROM orchids WHERE lower(trim(sci_name)) = lower(trim(p_sci_name))
  );

  DELETE FROM orchids
  WHERE lower(trim(sci_name)) = lower(trim(p_sci_name));
END;
$$;

GRANT EXECUTE ON FUNCTION public.unpublish_orchid(TEXT) TO authenticated;

COMMIT;
