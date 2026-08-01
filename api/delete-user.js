const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fmvkxvmrycsubjmkyaet.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
// Matches the superadmin dashboard's own login password (frontend/superadmin-dashboard.html).
// The dashboard has no real per-user Supabase session to verify, so this shared secret is
// the only thing gating this endpoint — keep it in sync with ADMIN_PASS in that file.
const SUPERADMIN_PASSWORD = process.env.SUPERADMIN_PASSWORD || 'admin';

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, X-Superadmin-Password');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  if (!SERVICE_ROLE_KEY) return res.status(500).json({ error: 'Server is not configured for this action (missing SUPABASE_SERVICE_ROLE_KEY).' });

  const suppliedPassword = req.headers['x-superadmin-password'] || '';
  if (suppliedPassword !== SUPERADMIN_PASSWORD) return res.status(401).json({ error: 'Not authenticated.' });

  const userId = String(req.body?.userId || '').trim();
  if (!userId) return res.status(400).json({ error: 'Missing userId.' });

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;

    await adminClient.from('user_profiles').delete().eq('id', userId);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Delete user error:', error);
    return res.status(500).json({ error: 'Failed to delete account', details: error.message });
  }
};
