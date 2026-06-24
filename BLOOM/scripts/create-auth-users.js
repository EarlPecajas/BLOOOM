import { createClient } from '@supabase/supabase-js'

// Usage:
// SUPABASE_URL=https://fmvkxvmrycsubjmkyaet.supabase.co SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY> node --experimental-modules scripts/create-auth-users.js

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://fmvkxvmrycsubjmkyaet.supabase.co'
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_SERVICE_ROLE_KEY environment variable with your service role key (do NOT commit it).')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

async function createUser(email, password, role, first_name, last_name) {
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { role, first_name, last_name }
  })

  if (error) {
    console.error('Error creating user', email, error)
  } else {
    console.log('Created user', email, 'id:', data.id)
  }
}

;(async () => {
  await createUser('carl@gmail.com', '12345', 'researcher', 'Carl', 'Researcher')
  await createUser('denr@gmail.com', '12345', 'denr', 'DENR', 'User')
  process.exit(0)
})()
