-- ── user_profiles table ──────────────────────────────────────────────────────
-- Tracks approval status, role, and basic info for every registered user.
-- The superadmin dashboard reads/writes this table to manage accounts.

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT        NOT NULL,
  full_name   TEXT,
  role        TEXT        NOT NULL DEFAULT 'researcher',
  status      TEXT        NOT NULL DEFAULT 'pending',  -- pending | approved | disabled
  phone       TEXT,
  birth_date  DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Allow anon key full access (superadmin dashboard uses anon key)
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- ── Auto-insert profile on new auth.users row ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role, status, phone, birth_date)
  VALUES (
    NEW.id,
    NEW.email,
    CONCAT(
      COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
      CASE WHEN NEW.raw_user_meta_data->>'last_name' IS NOT NULL
           THEN ' ' || (NEW.raw_user_meta_data->>'last_name')
           ELSE '' END
    ),
    COALESCE(NEW.raw_user_meta_data->>'role', 'researcher'),
    'pending',
    NEW.raw_user_meta_data->>'phone',
    CASE WHEN NEW.raw_user_meta_data->>'birth_date' ~ '^\d{4}-\d{2}-\d{2}$'
         THEN (NEW.raw_user_meta_data->>'birth_date')::DATE
         ELSE NULL END
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── Back-fill existing auth users who have no profile yet ─────────────────────
INSERT INTO public.user_profiles (id, email, full_name, role, status, phone, birth_date)
SELECT
  u.id,
  u.email,
  CONCAT(
    COALESCE(u.raw_user_meta_data->>'first_name', ''),
    CASE WHEN u.raw_user_meta_data->>'last_name' IS NOT NULL
         THEN ' ' || (u.raw_user_meta_data->>'last_name')
         ELSE '' END
  ),
  COALESCE(u.raw_user_meta_data->>'role', 'researcher'),
  'approved',   -- existing users are considered already approved
  u.raw_user_meta_data->>'phone',
  CASE WHEN u.raw_user_meta_data->>'birth_date' ~ '^\d{4}-\d{2}-\d{2}$'
       THEN (u.raw_user_meta_data->>'birth_date')::DATE
       ELSE NULL END
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.user_profiles p WHERE p.id = u.id);
