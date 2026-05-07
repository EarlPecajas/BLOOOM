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

  // Create base Supabase client with timeout configuration
  window.bloomSupabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey, {
    db: { schema: 'public' },
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    global: { 
      headers: {
        'X-Client-Info': 'bloom-frontend'
      },
      fetch: (url, options = {}) => {
        console.log('🔗 Supabase request:', url.toString().split('?')[0]);
        
        // Add timeout (10 seconds)
        const controller = new AbortController();
        const timeoutId = setTimeout(() => {
          console.warn('⏱️ Request timeout, aborting:', url);
          controller.abort();
        }, 10000);
        
        return fetch(url, {
          ...options,
          signal: controller.signal
        })
          .then(response => {
            clearTimeout(timeoutId);
            console.log('✓ Supabase response:', response.status, url.toString().split('?')[0]);
            return response;
          })
          .catch(error => {
            clearTimeout(timeoutId);
            console.error('✗ Supabase request failed:', error.message, url.toString().split('?')[0]);
            throw error;
          });
      }
    }
  });

  console.log('✓ Supabase client initialized:', supabaseUrl);
})();
