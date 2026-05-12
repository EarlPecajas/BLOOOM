# Supabase Region Migration Guide - BLOOM

**Current Setup:**
- Project ID: `hvyrngjfcvazxaoujduo`
- Current URL: `https://hvyrngjfcvazxaoujduo.supabase.co`
- Anon Key: `sb_publishable_UcgnIycusgu287rwsHIZGQ_CJkB7wQv` (PUBLIC - safe in frontend)
- Storage Bucket: `bloom-uploads`

---

## Migration Checklist

### Phase 1: Prepare New Supabase Project

- [ ] Log in to [Supabase Dashboard](https://app.supabase.com)
- [ ] Create new project in desired region
- [ ] Wait for project to be fully initialized (5-10 minutes)
- [ ] Note the new project credentials:
  - [ ] New Project ID: `_________________`
  - [ ] New URL: `https://_________________.supabase.co`
  - [ ] New Anon Key: `sb_publishable_________________________`
  - [ ] New Service Role Key: `(from Settings > API > Service role key)`

---

### Phase 2: Export Current Database

#### Option A: Using SQL Schema Files (Recommended for BLOOM)

The repository already contains all schema definitions in `backend/`. Execute these files in order in your **new** Supabase project:

**Sequence (in this order):**
1. `backend/schema.sql` — Core tables
2. `backend/add-species-sightings-table.sql` — Sightings table
3. `backend/assign-conservation-statuses.sql` — Conservation data
4. `backend/add-orchid-genus-list.sql` — Genus data
5. `backend/add-orchid-overview-view.sql` — Public view
6. `backend/add-public-approved-sightings-view.sql` — Public sightings view
7. `backend/refresh-public-approved-sightings-view-with-contributors.sql` — View update
8. `backend/supabase-only.sql` — RLS policies and permissions
9. `backend/add-denr-approved-sightings-view.sql` — DENR view (if needed)
10. `backend/add-flowering-season.sql` — Seasonal data
11. All other migration files in `backend/` as applicable

**Steps:**
- [ ] Open new Supabase project → SQL Editor
- [ ] Copy content from `backend/schema.sql`
- [ ] Paste and run each file sequentially
- [ ] Verify no errors in each execution

#### Option B: Using pg_dump (For Existing Data Export)

If you have existing data to migrate from current project:

```bash
# Export current database
pg_dump "postgresql://postgres:[PASSWORD]@db.[OLD_PROJECT_ID].supabase.co:5432/postgres" \
  --no-password \
  -c \
  -C \
  > bloom_backup.sql

# Restore to new database
psql "postgresql://postgres:[PASSWORD]@db.[NEW_PROJECT_ID].supabase.co:5432/postgres" \
  -f bloom_backup.sql
```

**Get credentials:**
- Current project: Supabase → Settings → Database → Connection string (PostgreSQL)
- Replace `[PASSWORD]` with your database password

---

### Phase 3: Migrate Data (If You Have Live Data)

#### Option 1: Direct Database Connection (Recommended)

```bash
# Install psql if not already installed
# macOS: brew install postgresql
# Windows: Download from https://www.postgresql.org/download/windows/
# Linux: sudo apt install postgresql-client

# Export data only (no schema)
pg_dump -h db.[CURRENT_PROJECT_ID].supabase.co \
  -U postgres \
  -d postgres \
  --data-only \
  --on-conflict-do-nothing \
  > bloom_data.sql

# Import to new project
psql -h db.[NEW_PROJECT_ID].supabase.co \
  -U postgres \
  -d postgres \
  -f bloom_data.sql
```

#### Option 2: Supabase Dashboard Export (Simple)

- [ ] Old Project → Settings → Backups
- [ ] Download latest backup
- [ ] New Project → Settings → Backups → Restore from backup (upload file)

#### Option 3: Manual Row-by-Row (If using API)

Use existing API endpoints to export data:
- [ ] `GET /api/orchids` → Export all orchids
- [ ] `GET /api/sightings` → Export all sightings
- [ ] Save as JSON, then use Supabase dashboard to bulk import

---

### Phase 4: Storage Bucket Migration

#### Option 1: Using Supabase CLI (Easiest)

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to current project (get access token from Supabase dashboard)
supabase projects list

# Download current storage bucket
supabase storage download bloom-uploads ./bloom-uploads-backup

# Link to new project
supabase projects list

# Upload to new project
supabase storage upload bloom-uploads ./bloom-uploads-backup/
```

#### Option 2: Manual via Dashboard

- [ ] Current Project → Storage → bloom-uploads
- [ ] Download all files individually (if small amount)
- [ ] New Project → Storage → Create bucket "bloom-uploads"
- [ ] Upload downloaded files

---

### Phase 5: Update Environment Variables

After migration, update these files:

#### 1. `frontend/config.js`

```javascript
window.BLOOM_SUPABASE_URL = 'https://[NEW_PROJECT_ID].supabase.co';
window.BLOOM_SUPABASE_ANON_KEY = 'sb_publishable_[NEW_ANON_KEY]';
window.BLOOM_STORAGE_BUCKET = 'bloom-uploads'; // Usually stays same
```

#### 2. Vercel Environment Variables

- [ ] Go to [Vercel Dashboard](https://vercel.com) → BLOOM project → Settings
- [ ] Update these secrets:
  - [ ] `DATABASE_URL` → New region database URL
  - [ ] `DATABASE_SSL` → Likely stays same (`true`)
  - [ ] `BLOOM_SUPABASE_URL` → `https://[NEW_PROJECT_ID].supabase.co`
  - [ ] `BLOOM_SUPABASE_ANON_KEY` → `sb_publishable_[NEW_ANON_KEY]`
  - [ ] `BLOOM_STORAGE_BUCKET` → `bloom-uploads`

**To get DATABASE_URL:**
- New Supabase Project → Settings → Database → Connection string (Prisma or URI)
- URI format: `postgresql://postgres:[PASSWORD]@db.[NEW_PROJECT_ID].supabase.co:5432/postgres`

#### 3. Local `.env` File (If You Have One)

Update any `.env` file with new credentials

---

### Phase 6: Test New Setup

- [ ] Update local config to point to new project
- [ ] Test frontend pages load:
  - [ ] Catalog page loads orchids
  - [ ] Gallery displays images from storage
  - [ ] Sightings view fetches data
- [ ] Test API endpoints:
  ```bash
  # Test orchids endpoint
  curl https://bloom.vercel.app/api/orchids
  
  # Test sightings endpoint  
  curl https://bloom.vercel.app/api/sightings
  ```
- [ ] Test authentication (sign in to researcher dashboard)
- [ ] Test submissions creation and retrieval
- [ ] Verify storage images load correctly
- [ ] Check browser console for errors

---

### Phase 7: Cleanup (When Satisfied)

- [ ] Delete backup files locally
- [ ] Keep old Supabase project available for 24-48 hours as safety backup
- [ ] After confirmation, delete old Supabase project

---

## Troubleshooting

### "Column not found" errors during schema creation
**Solution:** This likely means the schema wasn't applied in correct order. Start fresh:
1. Delete all tables in new project (SQL Editor: `DROP SCHEMA public CASCADE;`)
2. Recreate schema (SQL Editor: `CREATE SCHEMA public;`)
3. Run schema files again in order

### Images not loading after migration
**Solution:** Check storage bucket permissions:
1. New Project → Storage → bloom-uploads → Policies
2. Ensure bucket allows public read access
3. Verify image paths in `species_sightings` table are correct

### API endpoints returning 404 or unauthorized
**Solution:**
1. Verify `DATABASE_URL` is correctly set in Vercel
2. Trigger Vercel redeployment (Settings → Redeploy)
3. Check database connection string format (should be postgresql:// not postgres://)

### RLS policies blocking queries
**Solution:**
1. Verify `supabase-only.sql` was executed
2. Check that `GRANT` statements executed without errors
3. For server-side API endpoints, they use service role (bypass RLS) via `DATABASE_URL`
4. For browser client, queries must match RLS policies (authenticated users only)

---

## Key SQL Files Reference

| File | Purpose | Required |
|------|---------|----------|
| schema.sql | Core tables | ✅ YES |
| add-species-sightings-table.sql | Sightings table | ✅ YES |
| supabase-only.sql | RLS policies | ✅ YES |
| add-orchid-overview-view.sql | Public catalog view | ✅ YES |
| add-public-approved-sightings-view.sql | Public sightings view | ✅ YES |
| add-denr-approved-sightings-view.sql | DENR view | ⚠️ OPTIONAL |
| seed-genus-species.sql | Sample genus/species data | ⚠️ OPTIONAL |
| assign-conservation-statuses.sql | Conservation data | ⚠️ OPTIONAL |

---

## Need Help?

1. **Schema errors?** Check the SQL Editor for specific error messages
2. **Missing credentials?** Go to Supabase Project → Settings → API
3. **Connection issues?** Verify IP allowlist (Supabase usually allows all by default)
4. **Still stuck?** Check backend migration files for latest schema changes
