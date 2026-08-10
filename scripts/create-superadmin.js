const { createClient } = require('@supabase/supabase-js');

// Usage:
// SUPABASE_SERVICE_ROLE_KEY=<service_role_key> node scripts/create-superadmin.js
//
// Creates (or promotes, if the account already exists) a real Supabase Auth
// account with user_profiles.role = 'superadmin', so it can sign in through
// the normal signin.html page and reach /admin (superadmin-dashboard.html).
// Get the service role key from Supabase → Project Settings → API → service_role.
// Never commit that key or put it in any frontend file.

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fmvkxvmrycsubjmkyaet.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const EMAIL = process.env.SUPERADMIN_EMAIL || 'admin@bloom3d.app';
const PASSWORD = process.env.SUPERADMIN_PASSWORD || 'admin123';
const FULL_NAME = 'Super Admin';

if (!SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_SERVICE_ROLE_KEY environment variable with your service role key (do NOT commit it).');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

async function upsertProfile(userId) {
  const { error } = await supabase.from('user_profiles').upsert({
    id: userId,
    email: EMAIL,
    full_name: FULL_NAME,
    role: 'superadmin',
    status: 'approved',
    updated_at: new Date().toISOString()
  }, { onConflict: 'id' });
  if (error) throw error;
}

;(async () => {
  const { data: created, error: createError } = await supabase.auth.admin.createUser({
    email: EMAIL,
    password: PASSWORD,
    email_confirm: true,
    user_metadata: { role: 'superadmin', first_name: 'Super', last_name: 'Admin' }
  });

  if (!createError) {
    await upsertProfile(created.user.id);
    console.log('Created super-admin account:', EMAIL, 'id:', created.user.id);
    process.exit(0);
  }

  const alreadyExists = /already registered|already exists/i.test(createError.message || '');
  if (!alreadyExists) {
    console.error('Error creating super-admin account:', createError);
    process.exit(1);
  }

  console.log('Account already exists, looking it up to promote it instead...');
  const { data: list, error: listError } = await supabase.auth.admin.listUsers();
  if (listError) {
    console.error('Error listing users:', listError);
    process.exit(1);
  }
  const existing = list.users.find(u => u.email === EMAIL);
  if (!existing) {
    console.error('Could not find existing account for', EMAIL);
    process.exit(1);
  }
  await upsertProfile(existing.id);
  console.log('Promoted existing account to superadmin:', EMAIL, 'id:', existing.id);
  process.exit(0);
})().catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
