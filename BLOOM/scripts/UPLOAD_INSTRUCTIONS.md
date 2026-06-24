Upload images to Supabase storage and update DB

1) Purpose
- Upload local image files from `frontend/` to the `bloom-uploads` public storage bucket.
- Update rows in table `picture` whose `file_path` currently reference local paths (e.g. `./orchid1.webp`) to the public URL.

2) Requirements
- Node.js (16+ recommended)
- Your Supabase project `SUPABASE_URL` and a `SUPABASE_SERVICE_ROLE` key.

3) Install deps
```bash
npm init -y
npm install @supabase/supabase-js dotenv
```

4) Set environment variables
- Create a `.env` at the repo root with at least:
```
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_SERVICE_ROLE=eyJhbGci... (service_role key from Supabase settings)
```

5) Add images
- Place your image files in the `frontend/` directory (files like `orchid1.webp`, `orchid2.jpg`, `orchid3.webp`, `ghost orchid.webp`). The script will upload any common image extension it finds in `frontend/`.

6) Run the uploader
```bash
node scripts/upload-images.js
```

7) Verification
- After completion, check the Supabase storage UI for the `bloom-uploads` bucket and confirm objects under `orchids/`.
- Run (or open in browser console) on your site:
```js
await window.bloomSupabase.from('orchid_overview').select('image_url').limit(5)
```
Expect `image_url` to contain `https://<your-project>.supabase.co/storage/v1/object/public/bloom-uploads/...` URLs.

8) Notes and safety
- The script uses the `service_role` key which has elevated privileges — do not commit it to git. Use a short-lived or rotated key when possible.
- If your `picture.file_path` values use other formats, adjust the script matching logic.
