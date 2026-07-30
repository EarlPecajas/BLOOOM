const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fmvkxvmrycsubjmkyaet.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  if (!SERVICE_ROLE_KEY) return res.status(500).json({ error: 'Server is not configured for this action (missing SUPABASE_SERVICE_ROLE_KEY).' });

  const authHeader = req.headers.authorization || '';
  const callerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (!callerToken) return res.status(401).json({ error: 'Not authenticated.' });

  const userId = String(req.body?.userId || '').trim();
  if (!userId) return res.status(400).json({ error: 'Missing userId.' });

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const { data: callerData, error: callerError } = await adminClient.auth.getUser(callerToken);
    if (callerError || !callerData?.user) return res.status(401).json({ error: 'Invalid or expired session.' });

    const { data: callerProfile, error: profileError } = await adminClient
      .from('user_profiles').select('role').eq('id', callerData.user.id).single();
    if (profileError || callerProfile?.role !== 'admin') return res.status(403).json({ error: 'Only an admin account can delete accounts.' });

    if (userId === callerData.user.id) return res.status(400).json({ error: 'You cannot delete your own account from here.' });

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;

    await adminClient.from('user_profiles').delete().eq('id', userId);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Delete user error:', error);
    return res.status(500).json({ error: 'Failed to delete account', details: error.message });
  }
};
