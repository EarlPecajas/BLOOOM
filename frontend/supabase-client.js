(function () {
  const supabaseUrl = window.BLOOM_SUPABASE_URL;
  const supabaseAnonKey = window.BLOOM_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    console.warn('Supabase configuration is missing. Set BLOOM_SUPABASE_URL and BLOOM_SUPABASE_ANON_KEY in frontend/config.js.');
    return;
  }

  window.bloomSupabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey);
})();
