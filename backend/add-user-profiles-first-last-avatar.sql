BEGIN;

-- Web (researcher-dashboard.html) writes auth user_metadata keys
-- first_name/last_name/avatar_url (snake_case). The Flutter app writes a
-- disjoint camelCase key set (firstName/lastName/name/profilePhotoUrl) plus
-- its own 'name' combined field. Neither platform ever reads the other's
-- keys, so profile edits made on one side never show up on the other.
-- user_profiles is already shared (RLS disabled, keyed 1:1 to auth.users)
-- and updated live by both apps' status-gating reads, so it becomes the
-- single canonical store for these fields going forward; auth user_metadata
-- keeps being written too, for back-compat with any code still reading it.
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS first_name TEXT;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS last_name  TEXT;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Back-fill first/last/avatar for existing rows from whichever metadata
-- namespace the user actually signed up / last edited under.
UPDATE public.user_profiles p
SET
  first_name = COALESCE(
    p.first_name,
    u.raw_user_meta_data->>'first_name',
    u.raw_user_meta_data->>'firstName'
  ),
  last_name = COALESCE(
    p.last_name,
    u.raw_user_meta_data->>'last_name',
    u.raw_user_meta_data->>'lastName'
  ),
  avatar_url = COALESCE(
    p.avatar_url,
    u.raw_user_meta_data->>'avatar_url',
    u.raw_user_meta_data->>'profilePhotoUrl'
  )
FROM auth.users u
WHERE u.id = p.id
  AND (p.first_name IS NULL OR p.last_name IS NULL OR p.avatar_url IS NULL);

-- Split full_name as a last-resort fallback for rows still missing a
-- first/last split (e.g. only a combined 'name' metadata key existed).
UPDATE public.user_profiles
SET
  first_name = COALESCE(first_name, NULLIF(split_part(full_name, ' ', 1), '')),
  last_name  = COALESCE(last_name, NULLIF(substr(full_name, length(split_part(full_name, ' ', 1)) + 2), ''))
WHERE full_name IS NOT NULL
  AND (first_name IS NULL OR last_name IS NULL);

-- Recreate the signup trigger so new registrations also capture
-- first_name/last_name/avatar_url, reading both metadata key styles
-- defensively since signup can originate from either platform.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.user_profiles (
    id, email, full_name, role, status, phone, birth_date, affiliation,
    first_name, last_name, avatar_url
  )
  VALUES (
    NEW.id,
    NEW.email,
    CONCAT(
      COALESCE(NEW.raw_user_meta_data->>'first_name', NEW.raw_user_meta_data->>'firstName', ''),
      CASE WHEN COALESCE(NEW.raw_user_meta_data->>'last_name', NEW.raw_user_meta_data->>'lastName') IS NOT NULL
           THEN ' ' || COALESCE(NEW.raw_user_meta_data->>'last_name', NEW.raw_user_meta_data->>'lastName')
           ELSE '' END
    ),
    COALESCE(NEW.raw_user_meta_data->>'role', 'researcher'),
    'pending',
    NEW.raw_user_meta_data->>'phone',
    CASE WHEN NEW.raw_user_meta_data->>'birth_date' ~ '^\d{4}-\d{2}-\d{2}$'
         THEN (NEW.raw_user_meta_data->>'birth_date')::DATE
         ELSE NULL END,
    NEW.raw_user_meta_data->>'affiliation',
    COALESCE(NEW.raw_user_meta_data->>'first_name', NEW.raw_user_meta_data->>'firstName'),
    COALESCE(NEW.raw_user_meta_data->>'last_name', NEW.raw_user_meta_data->>'lastName'),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'profilePhotoUrl')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

COMMIT;
