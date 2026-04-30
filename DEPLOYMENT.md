# BLOOM Deployment Guide: Vercel + Supabase

This guide walks through deploying BLOOM to Vercel with Supabase as the database and storage backend.

## Prerequisites

1. A Supabase project (already created at `https://supabase.com`)
2. A Vercel account (`https://vercel.com`)
3. A Render or Railway account for the backend (or any Node.js hosting)

## Step 1: Prepare Supabase

### Database Setup
1. In your Supabase dashboard, go to **Project Settings** → **Database**
2. Note your Session Pooler connection string (for IPv4 networks)
3. Copy the `SUPABASE_URL` and `SUPABASE_ANON_KEY` from **Project Settings** → **API**

### Storage Setup
1. Go to **Storage** in your Supabase dashboard
2. Create a new bucket called `bloom-uploads`
3. Make it **Public** so files can be accessed via URL
4. Note the bucket name for later

### Import Database Schema
1. Run your SQL schema files against Supabase:
   ```bash
   node backend/run-sql-file.js backend/schema.sql
   # Then any other migration files as needed
   ```

## Step 2: Deploy Backend to Render or Railway

### Option A: Render.com

1. Push your code to GitHub (already done)
2. Go to `https://render.com` and sign in
3. Create a new **Web Service**
4. Connect your GitHub repository
5. Configure:
   - **Name**: `bloom-backend`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
6. Add environment variables:
   ```
   DATABASE_URL=postgresql://postgres.hvyrngjfcvazxaoujduo:Bloom3D%402026@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres
   DATABASE_SSL=true
   SUPABASE_URL=https://hvyrngjfcvazxaoujduo.supabase.co
   SUPABASE_ANON_KEY=<your_anon_key>
   PORT=3000
   ```
7. Deploy and note the URL (e.g., `https://bloom-backend.onrender.com`)

### Option B: Railway.app

1. Go to `https://railway.app`
2. Create a new project and connect GitHub
3. Select this repository
4. Add environment variables (same as Render above)
5. Deploy and note the URL

## Step 3: Configure Frontend for Vercel

Update `frontend/config.js` with your backend URL:

```javascript
window.BLOOM_API_BASE_URL = 'https://bloom-backend.onrender.com';
```

Or leave it empty if running locally:
```javascript
window.BLOOM_API_BASE_URL = '';
```

## Step 4: Deploy Frontend to Vercel

1. Go to `https://vercel.com/dashboard`
2. Click **Add New** → **Project**
3. Import your GitHub repository
4. Configure:
   - **Root Directory**: `frontend`
   - No environment variables needed
5. Deploy

## Step 5: Update Supabase Credentials (if needed)

If you want to use your actual Supabase credentials in the `.env` file:

```bash
# From your Supabase dashboard
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=your_actual_anon_key
```

## Architecture

```
┌─────────────────┐
│   Vercel        │ Frontend (HTML, CSS, JS)
│   (Frontend)    │ Points to backend via window.BLOOM_API_BASE_URL
└────────┬────────┘
         │ API calls to
         │
┌────────▼────────┐
│  Render/Railway │ Node.js Express Backend
│   (Backend)     │ Reads/writes to Supabase
└────────┬────────┘
         │ SQL queries
         │
┌────────▼────────┐
│   Supabase      │ PostgreSQL Database
│   (Database)    │ Stores all data
└────────┬────────┘
         │ File uploads
         │
┌────────▼────────┐
│  Supabase       │ Object Storage
│  Storage        │ Stores images/videos
└─────────────────┘
```

## File Upload Flow

1. Frontend uploads file to backend `/api/submissions`
2. Backend receives file in memory (multer)
3. Backend uploads to Supabase Storage (`bloom-uploads` bucket)
4. Backend stores Supabase URL in PostgreSQL
5. Frontend fetches files directly from Supabase URL

## Troubleshooting

### "Database connection failed"
- Verify `DATABASE_URL` is correct and accessible
- Check Supabase Session Pooler is being used (not direct connection)
- Ensure `DATABASE_SSL=true` is set

### "Media upload failed"
- Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set
- Check `bloom-uploads` bucket exists and is public
- Verify bucket policy allows public access

### Files not appearing
- Check Supabase Storage bucket is public
- Verify bucket name is `bloom-uploads`
- Test direct URL to file in browser

## Local Development

To run locally:

```bash
# Install dependencies
npm install

# Set .env variables (already configured)
cat .env

# Start backend
npm start

# Access frontend at http://localhost:3000
```

## Next Steps

- Set up CI/CD for automatic deployments on push
- Configure custom domain on Vercel
- Set up monitoring/alerts for backend uptime
- Implement backup strategy for database
