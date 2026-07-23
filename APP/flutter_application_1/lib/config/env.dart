// Supabase project configuration, overridable via --dart-define at build
// time (e.g. `flutter run --dart-define=SUPABASE_URL=...`). Defaults match
// the values web reads from frontend/config.js — the anon key is public by
// design (Supabase access control is enforced server-side), so this is
// about environment flexibility, not secrecy.

const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://fmvkxvmrycsubjmkyaet.supabase.co',
);

const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtdmt4dm1yeWNzdWJqbWt5YWV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1NjQyOTUsImV4cCI6MjA5NDE0MDI5NX0.lYomB0Ckg-b2cRHtylOQTpM9oAtOaLIto0T9nu-a5d8',
);

const String kStorageBucket = String.fromEnvironment(
  'SUPABASE_STORAGE_BUCKET',
  defaultValue: 'bloom-uploads',
);
