#!/usr/bin/env node
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

async function main() {
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE;
  if (!SUPABASE_URL || !SERVICE_ROLE) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE in environment. See scripts/UPLOAD_INSTRUCTIONS.md');
    process.exit(1);
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

  const frontendDir = path.join(__dirname, '..', 'frontend');
  if (!fs.existsSync(frontendDir)) {
    console.error('Cannot find frontend directory at', frontendDir);
    process.exit(1);
  }

  // Find image files referenced in the project (common extensions)
  const files = fs.readdirSync(frontendDir).filter(f => f.match(/\.(png|jpe?g|webp|avif)$/i));
  if (files.length === 0) {
    console.log('No image files found in frontend/. Place the files (orchid1.webp, orchid2.jpg, etc.) into frontend/ and re-run.');
    return;
  }

  console.log('Found image files:', files.join(', '));

  for (const filename of files) {
    const localPath = path.join(frontendDir, filename);
    const key = `orchids/${filename}`;
    const fileStream = fs.createReadStream(localPath);

    console.log('Uploading', filename, '->', key);
    const { error: uploadErr } = await supabase.storage.from('bloom-uploads').upload(key, fileStream, { upsert: true });
    if (uploadErr) {
      console.error('Upload failed for', filename, uploadErr.message || uploadErr);
      continue;
    }

    const publicUrl = `${SUPABASE_URL.replace(/\/$/, '')}/storage/v1/object/public/bloom-uploads/${encodeURIComponent(key)}`;
    console.log('Public URL:', publicUrl);

    // Update picture.file_path rows that reference the local path (like './orchid1.webp' or 'orchid1.webp')
    const localReferences = [`./${filename}`, filename];
    for (const ref of localReferences) {
      const { error: updateErr } = await supabase.from('picture').update({ file_path: publicUrl }).eq('file_path', ref);
      if (updateErr) {
        console.error('DB update failed for', ref, updateErr.message || updateErr);
      } else {
        console.log(`Updated picture.file_path for ${ref}`);
      }
    }
  }

  console.log('Upload script finished. Verify images in Supabase storage and frontend behavior.');
}

main().catch(err => {
  console.error(err && err.message ? err.message : err);
  process.exit(1);
});
