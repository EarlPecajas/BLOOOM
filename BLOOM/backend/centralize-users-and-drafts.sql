-- ============================================================
-- Migration: Centralize users & drafts for BLOOM3D
--
-- Run this once against the Supabase project via:
--   Dashboard > SQL Editor  OR  supabase db push
--
-- What it does
-- 1. Creates user_profiles table linked to Supabase auth.users.
--    This replaces the fragmented "user" / account / users tables
--    that were never connected to the real Supabase auth system.
-- 2. Adds a trigger so every new Supabase sign-up automatically
--    gets a matching profile row.
-- 3. Back-fills profiles for any existing Supabase auth users.
-- 4. Adds user_uuid (auth.users FK) to species_sightings so that
--    every sighting is properly tied to one canonical user identity.
-- 5. Ensures species_sightings can store mobile-origin drafts by
--    relaxing required columns via safe defaults.
-- 6. Adds RLS policies for user_profiles and drafts.
-- ============================================================

BEGIN;

-- ── 1. Canonical user profile table ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_profiles (
  id           UUID        PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  first_name   TEXT,
  last_name    TEXT,
  username     TEXT        UNIQUE,
  account_type TEXT        NOT NULL DEFAULT 'researcher'
    CHECK (account_type IN ('admin', 'denr', 'researcher', 'user')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Keep updated_at current on every write.
CREATE OR REPLACE FUNCTION set_updated_at_user_profiles()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER trg_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at_user_profiles();

-- ── 2. Auto-create profile on Supabase sign-up ───────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_first TEXT;
  v_last  TEXT;
  v_role  TEXT;
  v_full  TEXT;
BEGIN
  v_full  := COALESCE(NEW.raw_user_meta_data->>'name', '');
  v_first := COALESCE(
    NEW.raw_user_meta_data->>'first_name',
    split_part(v_full, ' ', 1),
    split_part(NEW.email, '@', 1)
  );
  v_last  := COALESCE(
    NEW.raw_user_meta_data->>'last_name',
    CASE WHEN strpos(v_full, ' ') > 0
         THEN substring(v_full FROM strpos(v_full, ' ') + 1)
         ELSE NULL END
  );
  v_role  := LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'researcher'));

  INSERT INTO public.user_profiles (id, first_name, last_name, account_type)
  VALUES (NEW.id, v_first, v_last, v_role)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();

-- ── 3. Back-fill profiles for existing Supabase auth users ───────────────────

INSERT INTO user_profiles (id, first_name, last_name, account_type)
SELECT
  u.id,
  COALESCE(
    u.raw_user_meta_data->>'first_name',
    split_part(COALESCE(u.raw_user_meta_data->>'name', ''), ' ', 1),
    split_part(u.email, '@', 1)
  ),
  COALESCE(
    u.raw_user_meta_data->>'last_name',
    CASE WHEN strpos(COALESCE(u.raw_user_meta_data->>'name',''),' ') > 0
         THEN substring(COALESCE(u.raw_user_meta_data->>'name','') FROM strpos(COALESCE(u.raw_user_meta_data->>'name',''),' ') + 1)
         ELSE NULL END
  ),
  LOWER(COALESCE(u.raw_user_meta_data->>'role', 'researcher'))
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM user_profiles p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

-- ── 4. Link species_sightings to auth.users UUID ─────────────────────────────

ALTER TABLE species_sightings
  ADD COLUMN IF NOT EXISTS user_uuid UUID REFERENCES auth.users (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_species_sightings_user_uuid
  ON species_sightings (user_uuid);

-- ── 5. Ensure mobile drafts can be stored without full field population ───────
-- Some columns that are NOT NULL in older schema versions need defaults so
-- that an in-progress draft from mobile can be saved before all fields are filled.

ALTER TABLE species_sightings
  ALTER COLUMN identification_confidence SET DEFAULT 'Unidentified';

-- The entry_id column is NOT NULL; mobile uses 'MOBILE-DRAFT-<draftId>'.
-- No schema change needed — just a convention enforced in app code.

-- ── 6. RLS: user_profiles ────────────────────────────────────────────────────

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own profile"   ON user_profiles;
DROP POLICY IF EXISTS "Users update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Service insert profile"   ON user_profiles;

-- Anyone can read their own profile (used for header display).
CREATE POLICY "Users read own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

-- Users may update their own profile.
CREATE POLICY "Users update own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- The trigger runs SECURITY DEFINER so it bypasses RLS; this policy handles
-- manual inserts (e.g. admin scripts).
CREATE POLICY "Service insert profile"
  ON user_profiles FOR INSERT
  WITH CHECK (true);

GRANT SELECT, UPDATE ON user_profiles TO authenticated;
GRANT INSERT ON user_profiles TO service_role;

-- ── 7. RLS: drafts in species_sightings ──────────────────────────────────────
-- Extend existing "Authenticated read sightings" / "Authenticated insert sightings"
-- policies (already defined in supabase-only.sql) to cover draft rows.
-- Those policies use auth.role() = 'authenticated' which already covers drafts.
-- We add a scoped policy so users can only see and manage THEIR OWN drafts.

DROP POLICY IF EXISTS "Owner manage own drafts" ON species_sightings;

CREATE POLICY "Owner manage own drafts"
  ON species_sightings
  FOR ALL
  USING (
    lower(coalesce(review_status,'')) = 'draft'
    AND (
      researcher_email = auth.jwt()->>'email'
      OR user_uuid = auth.uid()
    )
  )
  WITH CHECK (
    lower(coalesce(review_status,'')) = 'draft'
    AND (
      researcher_email = auth.jwt()->>'email'
      OR user_uuid = auth.uid()
    )
  );

COMMIT;
