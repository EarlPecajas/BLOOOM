const { createClient } = require('@supabase/supabase-js');

// Usage:
// SUPABASE_SERVICE_ROLE_KEY=<service_role_key> SUPERADMIN_EMAIL=admin@bloom3d.app SUPERADMIN_NEW_PASSWORD=<new_password> node scripts/reset-superadmin-password.js
//
// Force-sets the password for an existing Supabase Auth account, bypassing
// the (often broken/rate-limited) "send recovery email" flow in the
// Supabase dashboard. Use when you're locked out and email recovery fails.
// Get the service role key from Supabase → Project Settings → API → service_role.
// Never commit that key, and never put it in any frontend file.

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fmvkxvmrycsubjmkyaet.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const EMAIL = process.env.SUPERADMIN_EMAIL || 'admin@bloom3d.app';
const NEW_PASSWORD = process.env.SUPERADMIN_NEW_PASSWORD;

if (!SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_SERVICE_ROLE_KEY environment variable with your service role key (do NOT commit it).');
  process.exit(1);
}
if (!NEW_PASSWORD) {
  console.error('Set SUPERADMIN_NEW_PASSWORD environment variable with the new password you want to use.');
  process.exit(1);
}
if (NEW_PASSWORD.length < 6) {
  console.error('SUPERADMIN_NEW_PASSWORD must be at least 6 characters (Supabase minimum).');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

;(async () => {
  const { data: list, error: listError } = await supabase.auth.admin.listUsers();
  if (listError) {
    console.error('Error listing users:', listError);
    process.exit(1);
  }

  const user = list.users.find(u => u.email === EMAIL);
  if (!user) {
    console.error(`Could not find an account for ${EMAIL}`);
    process.exit(1);
  }

  const { error: updateError } = await supabase.auth.admin.updateUserById(user.id, {
    password: NEW_PASSWORD
  });
  if (updateError) {
    console.error('Error updating password:', updateError);
    process.exit(1);
  }

  console.log('Password reset successfully for', EMAIL, '(id:', user.id + ')');
  process.exit(0);
})().catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
