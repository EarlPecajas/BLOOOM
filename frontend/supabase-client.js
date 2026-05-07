(function () {
  const supabaseUrl = window.BLOOM_SUPABASE_URL;
  const supabaseAnonKey = window.BLOOM_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    console.warn('Supabase configuration is missing. Set BLOOM_SUPABASE_URL and BLOOM_SUPABASE_ANON_KEY in frontend/config.js.');
    return;
  }

  if (!window.supabase) {
    console.error('Supabase JS library not loaded. Make sure @supabase/supabase-js is loaded from CDN.');
    return;
  }

  // Create Supabase client with minimal config - let Supabase library handle fetch natively
  window.bloomSupabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey, {
    db: { schema: 'public' },
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });

  console.log('✓ Supabase client initialized:', supabaseUrl);
})();
