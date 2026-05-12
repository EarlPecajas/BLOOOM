// Shared dashboard utilities and authentication logic

let parsedActiveUser = {};
let activeRole = '';
let isAdminRole = false;
let isResearcherRole = false;
let authResolved = false;

// Initialize Supabase client from config
const supabaseUrl = window.BLOOM_SUPABASE_URL;
const supabaseKey = window.BLOOM_SUPABASE_ANON_KEY;
const supabaseClient = window.bloomSupabase || (supabaseUrl && supabaseKey && window.supabase ? window.supabase.createClient(supabaseUrl, supabaseKey) : null);

/**
 * Resolve the active user from Supabase session and localStorage
 */
async function resolveActiveUser() {
  // First, try Supabase session
  if (supabaseClient) {
    try {
      const { data: { session } } = await supabaseClient.auth.getSession();
      if (session?.user) {
        const role = String(session.user.user_metadata?.role || 'researcher').trim().toLowerCase();
        const parsedUser = {
          id: session.user.id,
          email: session.user.email,
          role,
          first_name: session.user.user_metadata?.first_name || '',
          last_name: session.user.user_metadata?.last_name || ''
        };
        localStorage.setItem('bloomUser', JSON.stringify(parsedUser));
        sessionStorage.setItem('bloomUser', JSON.stringify(parsedUser));
        return parsedUser;
      }
    } catch (error) {
      console.error('Supabase session error:', error.message);
    }
  }

  // Fallback to local/session storage only if no Supabase session exists yet.
  try {
    const stored = localStorage.getItem('bloomUser') || sessionStorage.getItem('bloomUser');
    if (stored) {
      return JSON.parse(stored);
    }
  } catch {}

  // Last resort: search all localStorage keys for session
  try {
    for (let k of Object.keys(localStorage)) {
      if (k.includes('supabase') || k.includes('auth')) {
        try {
          const candidate = JSON.parse(localStorage.getItem(k) || '{}');
            const sessionUser = candidate?.currentSession?.user || candidate?.session?.user || candidate?.user || null;
          if (sessionUser) {
            const role = String(sessionUser.user_metadata?.role || 'researcher').trim().toLowerCase();
            const parsedActiveUser = {
              id: sessionUser.id,
              email: sessionUser.email,
              role,
              first_name: sessionUser.user_metadata?.first_name || '',
              last_name: sessionUser.user_metadata?.last_name || ''
            };
            localStorage.setItem('bloomUser', JSON.stringify(parsedActiveUser));
            sessionStorage.setItem('bloomUser', JSON.stringify(parsedActiveUser));
            return parsedActiveUser;
          }
        } catch {}
      }
    }
  } catch {}

  return null;
}

/**
 * Update role state based on user
 */
function syncRoleState(user) {
  parsedActiveUser = user || {};
  activeRole = String(parsedActiveUser.role || '').trim().toLowerCase();
  // Treat both 'admin' and 'denr' as admin (DENR) roles for dashboard purposes
  isAdminRole = activeRole === 'admin' || activeRole === 'denr';
  isResearcherRole = activeRole === 'researcher' || activeRole === 'user';
}

/**
 * Sign out the current user
 */
async function signOut() {
  if (supabaseClient) {
    try { await supabaseClient.auth.signOut(); } catch (e) { /* ignore */ }
  }
  localStorage.removeItem('bloomUser');
  sessionStorage.removeItem('bloomUser');
  window.location.href = 'signin.html';
}

/**
 * Initialize authentication and redirect if needed
 */
async function initializeAuth(redirectCallback) {
  if (document?.body) {
    document.body.style.visibility = 'hidden';
  }

  // Resolve async, then decide action. Supabase session is authoritative.
  const resolved = await resolveActiveUser();
  if (!resolved) {
    authResolved = true;
    window.location.href = 'signin.html';
    return;
  }

  syncRoleState(resolved);
  authResolved = true;

  // Call the role-specific callback
  if (redirectCallback) {
    redirectCallback(resolved);
  }
}

/**
 * Fetch data helper with auth
 */
async function fetchWithAuth(endpoint, options = {}) {
  const defaultHeaders = {
    'Content-Type': 'application/json'
  };

  return fetch(endpoint, {
    ...options,
    headers: {
      ...defaultHeaders,
      ...options.headers
    }
  });
}
