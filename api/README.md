# BLOOM API Documentation

## Overview
These Vercel Functions bypass the IPv6-only Supabase REST API by using the free **Session Pooler** connection to PostgreSQL directly.

**No extra cost!** These endpoints use the existing free tier Session Pooler.

## Environment Variables Required

Add these to your `.env` file (already configured):

```
DATABASE_URL=postgresql://postgres.hvyrngjfcvazxaoujduo:[PASSWORD]@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres
DATABASE_SSL=true
```

## API Endpoints

### 1. GET `/api/orchids`
Get all orchids from the catalog.

**Query Parameters:**
- `id` (optional): Get specific orchid by ID

**Example:**
```bash
# Get all orchids
curl https://blooom-orpin.vercel.app/api/orchids

# Get specific orchid
curl https://blooom-orpin.vercel.app/api/orchids?id=5
```

**Response:**
```json
[
  {
    "id": 1,
    "name": "Acanthophippium mantinianum",
    "genus": "Acanthophippium",
    "common_name": "Species Name",
    "endemicity": "Endemic",
    "image_url": "..."
  }
]
```

---

### 2. GET `/api/sightings`
Get all public approved sightings (limit 100).

**Example:**
```bash
curl https://blooom-orpin.vercel.app/api/sightings
```

**Response:**
```json
[
  {
    "id": 1,
    "scientific_name": "Acanthophippium mantinianum",
    "common_name": "Common Name",
    "elevation_meters": 1200,
    "mountain_name": "Mt. Busa",
    "habitat_type": "Forest",
    "observation_date": "2024-01-15"
  }
]
```

---

### 3. POST `/api/sightings`
Submit a new sighting (Add Instance).

**Request Body:**
```json
{
  "scientific_name": "Acanthophippium mantinianum",
  "common_name": "Common Name",
  "elevation_meters": 1200,
  "mountain_name": "Mt. Busa",
  "habitat_type": "Forest",
  "observer_name": "John Doe",
  "observation_date": "2024-01-15"
}
```

**Example:**
```bash
curl -X POST https://blooom-orpin.vercel.app/api/sightings \
  -H "Content-Type: application/json" \
  -d '{
    "scientific_name": "Acanthophippium mantinianum",
    "common_name": "Flower",
    "elevation_meters": 1200,
    "mountain_name": "Mt. Busa",
    "habitat_type": "Forest",
    "observer_name": "Carl",
    "observation_date": "2026-05-08"
  }'
```

**Response (201 Created):**
```json
{
  "id": 123,
  "scientific_name": "Acanthophippium mantinianum",
  "created_at": "2026-05-08T10:00:00Z",
  ...
}
```

---

### 4. GET `/api/denr-sightings`
Get DENR approved sightings.

**Query Parameters:**
- `name` (optional): Get sightings for specific species name

**Example:**
```bash
# Get all DENR sightings
curl https://blooom-orpin.vercel.app/api/denr-sightings

# Get sightings for specific species
curl https://blooom-orpin.vercel.app/api/denr-sightings?name=Acanthophippium%20mantinianum
```

---

### 5. `/api/tripo3d` — Tripo3D AI 3D-model generation proxy
Keeps the Tripo3D API key server-side. Used by the DENR dashboard's "3D Image → Generate with AI" tab.

**Environment Variable Required:**
```
TRIPO_API_KEY=your_tripo_api_key_here
```
Get a key from https://platform.tripo3d.ai/api-keys

**POST `/api/tripo3d`** — create a generation task.

Image-to-3D (uses an orchid's existing catalog photo, no upload needed):
```json
{ "mode": "image", "imageUrl": "https://.../orchid-photo.jpg" }
```

Text-to-3D (fallback when no photo exists yet):
```json
{ "mode": "text", "prompt": "Vanda sanderiana orchid flower, photorealistic" }
```

**Response:**
```json
{ "task_id": "07764597-9c93-4eb9-92b6-4ea96a8c7d1a" }
```

**GET `/api/tripo3d?task_id=...`** — poll task status until `status` is `"success"`.

**Response:**
```json
{
  "task_id": "07764597-9c93-4eb9-92b6-4ea96a8c7d1a",
  "status": "success",
  "progress": 100,
  "output": { "model": "https://...glb", "pbr_model": "https://...glb" }
}
```

**GET `/api/tripo3d?model_url=<tripo glb url>`** — streams the generated model back through our own origin (avoids relying on Tripo's CORS headers for a direct browser fetch). Restricted to `*.tripo3d.com` / `*.tripo3d.ai` hosts.

The frontend downloads the resulting `.glb` via this route and re-uploads it to Supabase Storage using the same code path as the manual GLB upload, so the link saved to `orchids.model_3d_url` is permanent (Tripo's own URL is temporary).

---

## Frontend Usage

Update your frontend code to call these endpoints instead of REST API:

### Before (REST API - broken due to IPv6):
```javascript
const { data } = await bloomSupabase
  .from('orchid_overview')
  .select('*')
  .order('name.asc');
```

### After (Vercel Functions - FREE IPv4):
```javascript
const response = await fetch('/api/orchids');
const data = await response.json();
```

## Deployment
These functions are automatically deployed with your Vercel project. No additional setup needed!

## Cost
✅ **FREE!** - Uses existing Session Pooler connection included in Supabase free tier.
