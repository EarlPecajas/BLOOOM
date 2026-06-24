const express = require('express');
const { pool, query } = require('../db');

const router = express.Router();

async function findOrchidById(client, orchidId) {
  const result = await client.query(
    `SELECT
      o.orchid_id AS id,
      o.sci_name AS "scientificName",
      o.common_name AS "commonName",
      g.genus_name AS genus,
      o.date_discovered AS "createdAt",
      latest_picture.file_url AS "imageUrl",
      latest_location.lat,
      latest_location.lng
    FROM orchids o
    LEFT JOIN genus g ON g.genus_id = o.genus_id
    LEFT JOIN LATERAL (
      SELECT p.file_url
      FROM picture p
      WHERE p.orchid_id = o.orchid_id
      ORDER BY p.date_uploaded DESC, p.picture_id DESC
      LIMIT 1
    ) latest_picture ON TRUE
    LEFT JOIN LATERAL (
      SELECT
        ST_Y(ol.geom::geometry) AS lat,
        ST_X(ol.geom::geometry) AS lng
      FROM orchid_location ol
      WHERE ol.orchid_id = o.orchid_id
      ORDER BY ol.date_recorded DESC, ol.orchid_location_id DESC
      LIMIT 1
    ) latest_location ON TRUE
    WHERE o.orchid_id = $1`,
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
     RETURNING genus_id, genus_name`,
    [normalized]
  );

  return result.rows[0];
}

router.get('/', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT
        o.orchid_id AS id,
        o.sci_name AS "scientificName",
        o.common_name AS "commonName",
        g.genus_name AS genus,
        o.date_discovered AS "createdAt",
        latest_picture.file_url AS "imageUrl",
        latest_location.lat,
        latest_location.lng
      FROM orchids o
      LEFT JOIN genus g ON g.genus_id = o.genus_id
      LEFT JOIN LATERAL (
        SELECT p.file_url
        FROM picture p
        WHERE p.orchid_id = o.orchid_id
        ORDER BY p.date_uploaded DESC, p.picture_id DESC
        LIMIT 1
      ) latest_picture ON TRUE
      LEFT JOIN LATERAL (
        SELECT
          ST_Y(ol.geom::geometry) AS lat,
          ST_X(ol.geom::geometry) AS lng
        FROM orchid_location ol
        WHERE ol.orchid_id = o.orchid_id
        ORDER BY ol.date_recorded DESC, ol.orchid_location_id DESC
        LIMIT 1
      ) latest_location ON TRUE
      ORDER BY o.sci_name ASC`
    );

    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

router.get('/summary', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT
        (SELECT COUNT(*)::int FROM orchids) AS "totalSpecies",
        (SELECT COUNT(*)::int FROM picture WHERE status = 'pending') AS "pendingSubmissions",
        (SELECT COUNT(*)::int FROM orchid_location) AS "totalSightings",
        (SELECT COUNT(*)::int FROM picture) AS "totalImages"`
    );

    const latestSpecies = await query(
      `SELECT
        o.orchid_id AS id,
        o.sci_name AS "scientificName",
        o.common_name AS "commonName",
        p.file_url AS "imageUrl"
      FROM orchids o
      LEFT JOIN LATERAL (
        SELECT file_url
        FROM picture
        WHERE orchid_id = o.orchid_id
        ORDER BY date_uploaded DESC, picture_id DESC
        LIMIT 1
      ) p ON TRUE
      ORDER BY o.date_discovered DESC, o.orchid_id DESC
      LIMIT 1`
    );

    return res.json({
      ...(result.rows[0] || {}),
      latestSpecies: latestSpecies.rows[0] || null,
    });
  } catch (error) {
    return next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'Invalid species id.' });
    }

    const client = await pool.connect();
    const orchid = await findOrchidById(client, id);
    client.release();

    if (!orchid) {
      return res.status(404).json({ error: 'Species not found.' });
    }

    return res.json(orchid);
  } catch (error) {
    return next(error);
  }
});

router.post('/', async (req, res, next) => {
  const client = await pool.connect();

  try {
    const scientificName = String(req.body.scientificName || '').trim();
    const commonName = String(req.body.commonName || '').trim();
    const genusName = String(req.body.genus || '').trim();

    if (!scientificName) {
      return res.status(400).json({ error: 'scientificName is required.' });
    }

    await client.query('BEGIN');

    const genus = await ensureGenus(client, genusName);
    const upsertResult = await client.query(
      `INSERT INTO orchids (sci_name, common_name, genus_id)
       VALUES ($1, NULLIF($2, ''), $3)
       ON CONFLICT (sci_name)
       DO UPDATE SET
         common_name = COALESCE(EXCLUDED.common_name, orchids.common_name),
         genus_id = COALESCE(EXCLUDED.genus_id, orchids.genus_id)
       RETURNING orchid_id`,
      [scientificName, commonName, genus?.genus_id ?? null]
    );

    const orchidId = upsertResult.rows[0].orchid_id;
    const orchid = await findOrchidById(client, orchidId);

    await client.query('COMMIT');

    return res.status(201).json(orchid);
  } catch (error) {
    await client.query('ROLLBACK');
    return next(error);
  } finally {
    client.release();
  }
});


module.exports = router;
