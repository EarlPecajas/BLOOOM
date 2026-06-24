# Bloom API (PostgreSQL + PostGIS)

## 1. Run Fully Local with Docker Compose

From project root:

1. docker compose up --build
2. API will be available at http://localhost:4000
3. Health check: GET http://localhost:4000/health

## 2. Run API Locally (Node on host, DB in Docker)

1. Start only database:
   - docker compose up db
2. Open backend folder and install dependencies:
   - npm install
3. Copy .env.example to .env and adjust values if needed.
4. If you are using pgAdmin local server, set DB_NAME to `bloom_gis` in `.env`.
5. If `DATABASE_URL` is provided, it overrides DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASSWORD.
6. Start API:
   - npm run dev

## 3. Run with Supabase Postgres + PostGIS

1. In Supabase, open Database > Extensions and enable `postgis`.
2. Open SQL Editor in Supabase and run `backend/sql/init.sql` to create tables and seed data.
   - This script is aligned to the app workflow and orchid data model.
   - Core tables: `orchids`, `genus`, `picture`, `orchid_location`, `habitat_information`, `species_value`, `morphological_characteristics`, `province`, `municipality`, `mountain`, plus optional account/conservation tables.
3. In `backend/.env`, use your Supabase connection string:

```
PORT=4000
DATABASE_URL=postgresql://postgres.<project-ref>:<password>@<region>.pooler.supabase.com:6543/postgres?sslmode=require
DB_SSL=true
DB_SSL_REJECT_UNAUTHORIZED=true
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
SUPABASE_STORAGE_BUCKET=bloom-uploads
SUPABASE_STORAGE_PREFIX=draft-submissions
CORS_ORIGIN=*
```

4. Start the API from `backend`:
   - npm install
   - npm run dev
5. Verify integration:
   - GET http://localhost:4000/health
   - Expect: `postgisEnabled: true`
6. Optional: run through Docker Compose with Supabase overrides from project root (PowerShell):
   - $env:DATABASE_URL="<your_supabase_url>"
   - $env:DB_SSL="true"
   - $env:DB_SSL_REJECT_UNAUTHORIZED="true"
   - docker compose up --build api

Notes:

- `DATABASE_URL` (or `SUPABASE_DB_URL`) takes priority over DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASSWORD.
- If your local machine has certificate-chain issues, temporarily set `DB_SSL_REJECT_UNAUTHORIZED=false`.
- Keep using the same API routes; Flutter does not need Supabase-specific client code for this setup.
- Make sure the Supabase storage bucket is public, or replace public URL handling with signed URLs in the API.

## 4. EADDRINUSE on Port 4000

If `npm run dev` shows `EADDRINUSE: address already in use :::4000`, another service is already bound to port 4000 (usually Docker API container).

Use one runtime mode at a time:

1. Local Node API + Docker DB only:
   - docker compose stop api
   - docker compose up db
   - npm run dev
2. Full Docker stack:
   - docker compose up --build

You can also set a different API port in `backend/.env`, for example `PORT=4001`.

## 5. Main Endpoints

- GET /health
- POST /api/auth/signup
- POST /api/auth/login
- PATCH /api/auth/profile
- GET /api/species
- GET /api/species/summary
- POST /api/species
- GET /api/submissions
- POST /api/submissions
- GET /api/sightings
- GET /api/sightings/near?lat=5.9352&lng=125.0832&radiusMeters=3000
- GET /api/sightings/geojson
- POST /api/sightings
- POST /api/drafts/submit

## 6. Example Request Bodies

POST /api/submissions
{
"scientificName": "Vanda sanderiana",
"commonName": "Waling-waling",
"status": "pending",
"imageUrl": "https://example.com/upload.jpg"
}

POST /api/sightings
{
"scientificName": "Vanda sanderiana",
"commonName": "Waling-waling",
"lat": 5.9352,
"lng": 125.0832,
"notes": "Observed near Mt. Busa"
}

POST /api/drafts/submit
{
"draftId": "1713775100123456",
"scientificName": "Vanda sanderiana",
"commonName": "Waling-waling",
"latitude": "5.9352",
"longitude": "125.0832",
"images": [
{
"fileName": "orchid.jpg",
"contentType": "image/jpeg",
"photoCredit": "Research Team",
"base64Data": "<base64-image-data>"
}

POST /api/auth/signup
{
"name": "Researcher One",
"email": "researcher@example.com",
"password": "secret123",
"location": "Mt. Busa"
}

POST /api/auth/login
{
"email": "researcher@example.com",
"password": "secret123"
}

PATCH /api/auth/profile
{
"accountId": 1,
"name": "Researcher Updated",
"username": "researcherupdated",
"location": "Sarangani",
"profilePhotoBase64": ""
}

## 7. DENR SQL Sample Files

You provided:

- `orchid_database.sql`
- `orchid_full_species.sql`

These files use a DENR analytical structure (`study`, `species`, `species_distribution`, etc.) that is different from the app runtime schema (`orchids`, `orchid_location`, `picture`, etc.).

Recommended setup for this app:

1. Run `backend/sql/init.sql` for the app runtime schema.
2. Keep DENR scripts in a separate database/schema for reference, OR transform DENR data before importing into app tables.

This avoids table-name collisions and accidental drops against runtime tables.
],
"contributors": [
{
"name": "Jane Doe",
"position": "Field Biologist/Botanist"
}
]
}
