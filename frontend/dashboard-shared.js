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
            .select('status, role, affiliation, first_name, last_name, avatar_url')
            .eq('id', session.user.id)
            .single();
          if (profile) {
            parsedUser.status = profile.status || 'approved';
            parsedUser.role = profile.role || parsedUser.role;
            parsedUser.affiliation = profile.affiliation || '';
            // user_profiles is the cross-platform source of truth for
            // name/photo (shared with the mobile app); auth user_metadata
            // is only a fallback for accounts that predate this table sync.
            parsedUser.first_name = profile.first_name || parsedUser.first_name;
            parsedUser.last_name = profile.last_name || parsedUser.last_name;
            parsedUser.avatar_url = profile.avatar_url || parsedUser.avatar_url;
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
  // Set up realtime notifications for this user (keeps the notif badge live)
  try {
    setupRealtimeNotifications(resolved);
  } catch (e) { /* ignore */ }

  // Call the role-specific callback
  if (redirectCallback) {
    redirectCallback(resolved);
  }
}

/**
 * Subscribe to realtime changes and update notification UI when relevant.
 * Works for both researcher (per-email) and admin/DENR (global) views.
 */
function setupRealtimeNotifications(user) {
  if (!window.bloomSupabase) return;
  const email = String(user?.email || '').trim().toLowerCase();

  // Helper to safely call the page-level loader if available
  async function triggerLoad(rec) {
    try {
      // Prefer direct badge update for immediate feedback
      const emailFromRec = String(rec?.researcher_email || '').trim().toLowerCase();
      const targetEmail = emailFromRec || String(user?.email || '').trim().toLowerCase();
      await updateNotificationBadge(targetEmail);
      // Also call full loader if present
      if (typeof loadNotifItems === 'function') loadNotifItems();
    } catch (_) {
      try { if (typeof loadNotifItems === 'function') loadNotifItems(); } catch (_) {}
    }
  }

  // Query DB for counts and immediately update the badge and card
  async function updateNotificationBadge(email) {
    try {
      if (!window.bloomSupabase) return;
      let query = bloomSupabase.from('species_sightings').select('review_status');
      if (email) query = query.eq('researcher_email', email);
      query = query.neq('review_status', 'draft');
      const { data } = await query;
      const rows = Array.isArray(data) ? data : [];
      const pending  = rows.filter(s => s.review_status === 'pending').length;
      const approved = rows.filter(s => s.review_status === 'approved').length;
      const rejected = rows.filter(s => s.review_status === 'rejected').length;
      const revision = rows.filter(s => s.review_status === 'revision').length;
      const urgentCount = revision + rejected;
      const badge = document.getElementById('notif-badge');
      if (badge) { badge.hidden = urgentCount === 0; badge.textContent = urgentCount > 9 ? '9+' : urgentCount; }
      try { updateNotifCard(pending, approved, rejected, revision); } catch (_) {}
    } catch (err) {
      // ignore errors
    }
  }

  try {
    // Newer Supabase client API: channel().on('postgres_changes', ...).subscribe()
    if (typeof bloomSupabase.channel === 'function') {
      const chan = bloomSupabase.channel('public-species-sightings');
      chan.on('postgres_changes', { event: '*', schema: 'public', table: 'species_sightings' }, (payload) => {
        const rec = payload?.record || payload?.new || payload?.old || {};
        // If researcher, only trigger when their email is involved
        if (email) {
          if (String(rec.researcher_email || '').trim().toLowerCase() === email) triggerLoad(rec);
        } else {
          // Admins and anonymous viewers: trigger for any change
          triggerLoad(rec);
        }
      });
      // subscribe (ignore returned promise/result)
      try { chan.subscribe(); } catch (_) {}
      return;
    }

    // Fallback older API: .from(...).on(...).subscribe()
    if (email && typeof bloomSupabase.from === 'function') {
      try {
        bloomSupabase.from(`species_sightings:researcher_email=eq.${email}`)
          .on('*', () => triggerLoad())
          .subscribe();
        return;
      } catch (_) {}
    }

    // Global fallback
    if (typeof bloomSupabase.from === 'function') {
      try {
        bloomSupabase.from('species_sightings').on('*', () => triggerLoad()).subscribe();
      } catch (_) {}
    }
  } catch (err) {
    console.error('setupRealtimeNotifications failed', err && err.message ? err.message : err);
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

// Ensure there is at most one visible required asterisk per label.
function dedupeRequiredAsterisks(root = document) {
  try {
    const labels = (root || document).querySelectorAll ? (root || document).querySelectorAll('label') : [];
    labels.forEach(label => {
      const stars = label.querySelectorAll('.required-asterisk');
      if (stars && stars.length > 1) {
        // Keep the first occurrence and remove subsequent ones to avoid visual doubling
        Array.from(stars).forEach((s, i) => { if (i > 0) s.remove(); });
      }
    });
  } catch (e) { /* ignore */ }
}

// Run dedupe on initial load and whenever DOM mutations occur that might add asterisks.
try {
  // Run once after DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => dedupeRequiredAsterisks(document));
  } else {
    dedupeRequiredAsterisks(document);
  }

  // Observe for dynamic changes and dedupe on the fly
  const _asteriskObserver = new MutationObserver(mutations => {
    let dirty = false;
    for (const m of mutations) {
      if (m.addedNodes && m.addedNodes.length) { dirty = true; break; }
      if (m.type === 'attributes' && String(m.attributeName).toLowerCase().includes('class')) { dirty = true; break; }
    }
    if (dirty) {
      dedupeRequiredAsterisks(document);
    }
  });
  _asteriskObserver.observe(document.documentElement || document.body, { childList: true, subtree: true, attributes: true });
} catch (e) { /* ignore */ }
