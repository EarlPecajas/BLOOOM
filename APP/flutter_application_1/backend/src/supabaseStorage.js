const crypto = require('crypto');

const DEFAULT_BUCKET = 'bloom-uploads';
const DEFAULT_PREFIX = 'draft-submissions';

function normalizeBaseUrl(value) {
  return String(value || '').trim().replace(/\/+$/, '');
}

function normalizePathSegment(value, fallback) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');

  return normalized || fallback;
}

function normalizePrefix(value) {
  return String(value || DEFAULT_PREFIX)
    .trim()
    .replace(/^\/+/, '')
    .replace(/\/+$/, '');
}

function resolveConfig() {
  return {
    supabaseUrl: normalizeBaseUrl(process.env.SUPABASE_URL),
    serviceRoleKey: String(process.env.SUPABASE_SERVICE_ROLE_KEY || '').trim(),
    bucket: String(process.env.SUPABASE_STORAGE_BUCKET || DEFAULT_BUCKET).trim(),
    prefix: normalizePrefix(process.env.SUPABASE_STORAGE_PREFIX),
  };
}

function isSupabaseStorageConfigured() {
  const config = resolveConfig();
  return Boolean(config.supabaseUrl && config.serviceRoleKey && config.bucket);
}

function ensureConfig() {
  const config = resolveConfig();
  const missing = [];

  if (!config.supabaseUrl) {
    missing.push('SUPABASE_URL');
  }

  if (!config.serviceRoleKey) {
    missing.push('SUPABASE_SERVICE_ROLE_KEY');
  }

  if (!config.bucket) {
    missing.push('SUPABASE_STORAGE_BUCKET');
  }

  if (missing.length > 0) {
    throw new Error(
      `Supabase storage is not configured. Missing: ${missing.join(', ')}`
    );
  }

  return config;
}

function inferExtension(fileName, contentType) {
  const normalizedName = String(fileName || '').trim().toLowerCase();
  const extension = normalizedName.includes('.')
    ? normalizedName.split('.').pop() || ''
    : '';

  if (extension === 'jpg' || extension === 'jpeg') {
    return 'jpg';
  }

  if (extension === 'png' || extension === 'webp' || extension === 'gif') {
    return extension;
  }

  const normalizedType = String(contentType || '').trim().toLowerCase();

  if (normalizedType.includes('png')) {
    return 'png';
  }

  if (normalizedType.includes('webp')) {
    return 'webp';
  }

  if (normalizedType.includes('gif')) {
    return 'gif';
  }

  return 'jpg';
}

function inferContentType(contentType, extension) {
  const normalizedType = String(contentType || '').trim().toLowerCase();

  if (normalizedType.startsWith('image/')) {
    return normalizedType;
  }

  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'image/jpeg';
  }
}

function encodeObjectPath(path) {
  return path
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}

function buildObjectPath({ prefix, scientificName, draftId, fileName, imageIndex, contentType }) {
  const safeSpecies = normalizePathSegment(scientificName, 'unknown-species');
  const safeDraftId = normalizePathSegment(draftId, 'draft');
  const extension = inferExtension(fileName, contentType);
  const uniquePart = crypto.randomUUID();

  return `${prefix}/${safeSpecies}/${safeDraftId}-${imageIndex + 1}-${uniquePart}.${extension}`;
}

async function uploadImageToSupabaseStorage({
  imageBytes,
  fileName,
  contentType,
  scientificName,
  draftId,
  imageIndex,
}) {
  const config = ensureConfig();

  const objectPath = buildObjectPath({
    prefix: config.prefix,
    scientificName,
    draftId,
    fileName,
    imageIndex,
    contentType,
  });

  const extension = inferExtension(fileName, contentType);
  const uploadContentType = inferContentType(contentType, extension);
  const encodedPath = encodeObjectPath(objectPath);
  const encodedBucket = encodeURIComponent(config.bucket);

  const uploadUrl = `${config.supabaseUrl}/storage/v1/object/${encodedBucket}/${encodedPath}`;

  const response = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.serviceRoleKey}`,
      apikey: config.serviceRoleKey,
      'Content-Type': uploadContentType,
      'x-upsert': 'false',
    },
    body: imageBytes,
  });

  if (!response.ok) {
    const details = (await response.text()).trim();
    throw new Error(
      `Supabase upload failed (${response.status}). ${details || 'No details returned.'}`
    );
  }

  const publicUrl = `${config.supabaseUrl}/storage/v1/object/public/${encodedBucket}/${encodedPath}`;

  return {
    objectPath,
    publicUrl,
  };
}

async function deleteImageFromSupabaseStorage(objectPath) {
  if (!objectPath) {
    return;
  }

  const config = resolveConfig();
  if (!config.supabaseUrl || !config.serviceRoleKey || !config.bucket) {
    return;
  }

  const encodedBucket = encodeURIComponent(config.bucket);
  const encodedPath = encodeObjectPath(objectPath);
  const deleteUrl = `${config.supabaseUrl}/storage/v1/object/${encodedBucket}/${encodedPath}`;

  try {
    await fetch(deleteUrl, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${config.serviceRoleKey}`,
        apikey: config.serviceRoleKey,
      },
    });
  } catch (_) {
    // Best effort cleanup only.
  }
}

module.exports = {
  isSupabaseStorageConfigured,
  uploadImageToSupabaseStorage,
  deleteImageFromSupabaseStorage,
};
