// Shared dashboard utilities and authentication logic

const BLOOM_TOAST_ICONS = {
  success: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"></path></svg>',
  error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><path d="M15 9l-6 6M9 9l6 6"></path></svg>',
  warning: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z"></path><path d="M12 9v4"></path><path d="M12 17h.01"></path></svg>',
  info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><path d="M12 16v-4"></path><path d="M12 8h.01"></path></svg>'
};

/**
 * Show a dismissible toast notification instead of a blocking native alert().
 * @param {string} message
 * @param {'success'|'error'|'warning'|'info'} [type]
 * @param {number} [duration] ms before auto-dismiss
 */
function showToast(message, type, duration) {
  type = BLOOM_TOAST_ICONS[type] ? type : 'info';
  duration = duration || 5000;

  let container = document.getElementById('bloom-toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'bloom-toast-container';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  toast.className = `bloom-toast bloom-toast--${type}`;
  toast.innerHTML = `
    <span class="bloom-toast-icon">${BLOOM_TOAST_ICONS[type]}</span>
    <span class="bloom-toast-msg"></span>
    <button type="button" class="bloom-toast-close" aria-label="Dismiss">&times;</button>
  `;
  toast.querySelector('.bloom-toast-msg').textContent = message;

  const remove = () => {
    toast.classList.add('leaving');
    setTimeout(() => toast.remove(), 200);
  };
  toast.querySelector('.bloom-toast-close').addEventListener('click', remove);

  container.appendChild(toast);
  const timer = setTimeout(remove, duration);
  toast.addEventListener('mouseenter', () => clearTimeout(timer));
}

let parsedActiveUser = {};
let activeRole = '';
let isAdminRole = false;
let isResearcherRole = false;
let isPendingApproval = false;
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
          status: 'approved',
          affiliation: '',
          first_name: session.user.user_metadata?.first_name || '',
          last_name: session.user.user_metadata?.last_name || '',
          avatar_url: session.user.user_metadata?.avatar_url || ''
        };
        // Re-check approval status/role from user_profiles on every load so an
        // admin approving (or disabling) an account takes effect without
        // requiring the user to sign out and back in.
        try {
          const { data: profile } = await supabaseClient
            .from('user_profiles')
            .select('status, role, affiliation')
            .eq('id', session.user.id)
            .single();
          if (profile) {
            parsedUser.status = profile.status || 'approved';
            parsedUser.role = profile.role || parsedUser.role;
            parsedUser.affiliation = profile.affiliation || '';
          }
        } catch (_) {}
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
              last_name: sessionUser.user_metadata?.last_name || '',
              avatar_url: sessionUser.user_metadata?.avatar_url || ''
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
  isResearcherRole = !isAdminRole;
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
