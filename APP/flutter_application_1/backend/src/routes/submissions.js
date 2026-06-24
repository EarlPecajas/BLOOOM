const express = require('express');
const { pool, query } = require('../db');

const router = express.Router();

const ALLOWED_STATUS = new Set(['pending', 'approved', 'rejected']);

function parseStatus(value) {
  const normalized = String(value || 'pending').trim().toLowerCase();
  return ALLOWED_STATUS.has(normalized) ? normalized : null;
}

function inferFileType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) {
    return null;
  }

  if (normalized.startsWith('image/')) {
    return normalized;
  }

  if (normalized.endsWith('.png')) {
    return 'image/png';
  }

  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }

  if (normalized.endsWith('.gif')) {
    return 'image/gif';
  }

  return 'image/jpeg';
}

async function findOrchidById(client, orchidId) {
  const result = await client.query(
    `SELECT
      orchid_id,
      sci_name,
      common_name
    FROM orchids
    WHERE orchid_id = $1`,
    [orchidId]
  );

  if (result.rowCount === 0) {
    return null;
  }

  return result.rows[0];
}

async function ensureGenus(client, genusName) {
  const normalized = String(genusName || '').trim();
  if (!normalized) {
    return null;
  }

  const result = await client.query(
    `INSERT INTO genus (genus_name)
     VALUES ($1)
     ON CONFLICT (genus_name)
     DO UPDATE SET genus_name = EXCLUDED.genus_name
     RETURNING genus_id`,
    [normalized]
  );

  return result.rows[0].genus_id;
}

async function resolveOrchid(client, { orchidId, scientificName, commonName, genusName }) {
  if (Number.isInteger(orchidId) && orchidId > 0) {
    const existing = await findOrchidById(client, orchidId);
    if (!existing) {
      return null;
    }

    return existing;
  }

  if (!scientificName) {
    return null;
  }

  const genusId = await ensureGenus(client, genusName);
  const upsert = await client.query(
    `INSERT INTO orchids (sci_name, common_name, genus_id)
     VALUES ($1, NULLIF($2, ''), $3)
     ON CONFLICT (sci_name)
     DO UPDATE SET
       common_name = COALESCE(EXCLUDED.common_name, orchids.common_name),
       genus_id = COALESCE(EXCLUDED.genus_id, orchids.genus_id)
     RETURNING orchid_id, sci_name, common_name`,
    [scientificName, commonName, genusId]
  );

  return upsert.rows[0];
}

router.get('/', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT
        p.picture_id AS id,
        p.orchid_id AS "speciesId",
        o.sci_name AS "scientificName",
        o.common_name AS "commonName",
        p.file_url AS "imageUrl",
        p.status,
        p.photo_credit AS "photoCredit",
        p.date_uploaded AS "uploadedAt"
      FROM picture p
      JOIN orchids o ON o.orchid_id = p.orchid_id
      ORDER BY p.date_uploaded DESC, p.picture_id DESC`
    );

    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

router.post('/', async (req, res, next) => {
  const speciesId = Number(req.body.speciesId);
  const scientificName = String(req.body.scientificName || '').trim();
  const commonName = String(req.body.commonName || '').trim();
  const genus = String(req.body.genus || '').trim();
  const imageUrl = String(req.body.imageUrl || '').trim();
  const photoCredit = String(req.body.photoCredit || '').trim();
  const fileType = inferFileType(req.body.fileType || imageUrl);
  const fileSize = Number(req.body.fileSize);
  const uploadedAtRaw = String(req.body.uploadedAt || '').trim();
  const status = parseStatus(req.body.status);

  if (status == null) {
    return res
      .status(400)
      .json({ error: 'status must be pending, approved, or rejected.' });
  }

  if (!Number.isInteger(speciesId) && !scientificName) {
    return res.status(400).json({
      error: 'Provide speciesId or scientificName/commonName.',
    });
  }

  if (!imageUrl) {
    return res.status(400).json({ error: 'imageUrl is required.' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const orchid = await resolveOrchid(client, {
      orchidId: speciesId,
      scientificName,
      commonName,
      genusName: genus,
    });

    if (!orchid) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'speciesId not found.' });
    }

    const uploadedAt = uploadedAtRaw || null;
    const created = await client.query(
      `INSERT INTO picture (orchid_id, file_url, file_type, file_size, status, photo_credit, date_uploaded)
       VALUES (
         $1,
         $2,
         NULLIF($3, ''),
         CASE WHEN $4::int IS NULL OR $4::int < 0 THEN NULL ELSE $4::int END,
         $5,
         NULLIF($6, ''),
         COALESCE($7::timestamptz, NOW())
       )
       RETURNING
         picture_id AS id,
         orchid_id AS "speciesId",
         file_url AS "imageUrl",
         status,
         photo_credit AS "photoCredit",
         date_uploaded AS "uploadedAt"`,
      [
        orchid.orchid_id,
        imageUrl,
        fileType,
        Number.isFinite(fileSize) ? Math.trunc(fileSize) : null,
        status,
        photoCredit,
        uploadedAt,
      ]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      ...created.rows[0],
      scientificName: orchid.sci_name,
      commonName: orchid.common_name,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    return next(error);
  } finally {
    client.release();
  }
});

module.exports = router;
