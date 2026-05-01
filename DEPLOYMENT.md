# BLOOM Deployment Guide: Supabase Only

This version of BLOOM deploys as a static frontend on Vercel and talks directly to Supabase for auth, database reads/writes, and storage.

## 1. Prepare Supabase

Run [backend/supabase-only.sql](backend/supabase-only.sql) in the Supabase SQL editor.

If you use incremental SQL migrations instead of the full Supabase bootstrap script, also run [backend/add-orchid-overview-view.sql](backend/add-orchid-overview-view.sql).

If the catalog is empty after setup, run [backend/seed-genus-species.sql](backend/seed-genus-species.sql) to populate the `genus` and `orchids` tables with initial orchid records.

That SQL file:
- Creates the `orchid_overview` view used by the catalog and dashboard
- Enables the required RLS policies for the tables used by the app
- Creates the `bloom-uploads` storage bucket if it does not already exist

Then confirm these items in Supabase:
- `bloom-uploads` bucket exists and is public
- Your project has a valid `SUPABASE_URL`
- Your project has a valid publishable key in `frontend/config.js`

## 2. Deploy to Vercel

Deploy the `frontend` folder as the Vercel project root.

The frontend already loads:
- [frontend/config.js](frontend/config.js)
- [frontend/supabase-client.js](frontend/supabase-client.js)
- the Supabase browser client from a CDN

No backend service is required.

## 3. Verify the App

After deployment, test these flows:
1. Sign up and sign in
2. Open the orchid catalog
3. Submit a researcher record with photos or video
4. Check that the record appears in `species_sightings`
5. Check that uploaded files appear in Supabase Storage under `bloom-uploads`

## 4. If Something Fails

If the app cannot read or write data:
- Re-run [backend/supabase-only.sql](backend/supabase-only.sql)
- Make sure RLS policies are enabled on the relevant tables
- Make sure the bucket is public and the publishable key in `frontend/config.js` is current
