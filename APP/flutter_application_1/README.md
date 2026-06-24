# Bloom

Flutter mobile app for orchid cataloging, submissions, and sightings.

## Run Flutter App

1. flutter pub get
2. flutter run

## Backend API (PostgreSQL + PostGIS)

Backend source is in [backend/README.md](backend/README.md).

Quick start from project root:

1. docker compose up --build
2. API base URL: http://localhost:4000
3. Health endpoint: http://localhost:4000/health

## Supabase (Hosted Postgres + PostGIS)

You can keep this app architecture and simply point the Node API to Supabase:

1. Enable `postgis` in your Supabase project.
2. Run `backend/sql/init.sql` in Supabase SQL Editor.
3. Configure `backend/.env` with Supabase:

- `DATABASE_URL`
- `DB_SSL=true`
- `DB_SSL_REJECT_UNAUTHORIZED=true`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_STORAGE_BUCKET` (public bucket)
- `SUPABASE_STORAGE_PREFIX`

4. Start API from `backend` with `npm run dev`.

Details are in [backend/README.md](backend/README.md).

## Connect Flutter to API Host

The app now calls backend APIs for:

- Login / Sign up / Profile updates (`/api/auth/*`)
- Catalog species listing (`/api/species`)
- Uploads status (`/api/submissions`)
- Map heat points (`/api/sightings`)
- Draft submit flow (`/api/drafts/submit`)

- Default URL behavior:
  - Android emulator uses http://10.0.2.2:4000
  - Web/Desktop uses http://localhost:4000

For physical phones or custom hosts, pass API_BASE_URL:

flutter run --dart-define=API_BASE_URL=http://YOUR_MACHINE_IP:4000

Example:

flutter run --dart-define=API_BASE_URL=http://192.168.1.15:4000

For installed APK/IPA on a physical device, use your machine LAN IP in `API_BASE_URL` and ensure firewall allows inbound traffic on your API port.
