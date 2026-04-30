const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

let supabase = null;

function getSupabaseClient() {
  if (!supabase) {
    if (!supabaseUrl || !supabaseKey) {
      throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY environment variables are required for file uploads");
    }
    supabase = createClient(supabaseUrl, supabaseKey);
  }
  return supabase;
}

async function uploadFile(bucket, filePath, fileBuffer, mimeType) {
  const client = getSupabaseClient();
  
  const { data, error } = await client.storage
    .from(bucket)
    .upload(filePath, fileBuffer, {
      contentType: mimeType,
      upsert: false
    });

  if (error) {
    throw new Error(`Failed to upload file to Supabase Storage: ${error.message}`);
  }

  const { data: urlData } = client.storage
    .from(bucket)
    .getPublicUrl(filePath);

  return urlData.publicUrl;
}

async function deleteFile(bucket, filePath) {
  const client = getSupabaseClient();
  
  const { error } = await client.storage
    .from(bucket)
    .remove([filePath]);

  if (error) {
    throw new Error(`Failed to delete file from Supabase Storage: ${error.message}`);
  }
}

module.exports = { uploadFile, deleteFile };
