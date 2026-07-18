BEGIN;

ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS affiliation TEXT;

-- Recreate the signup trigger so new registrations also capture affiliation
-- from the signUp() user_metadata payload.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role, status, phone, birth_date, affiliation)
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
         ELSE NULL END,
    NEW.raw_user_meta_data->>'affiliation'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

COMMIT;
