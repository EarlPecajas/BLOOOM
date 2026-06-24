const express = require('express');
const { pool, query } = require('../db');

const router = express.Router();

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

async function resolveOrchidId(client, orchidId, scientificName, commonName, genusName) {
  if (Number.isInteger(orchidId) && orchidId > 0) {
    const orchidCheck = await client.query(
      'SELECT orchid_id FROM orchids WHERE orchid_id = $1',
      [orchidId]
    );

    if (orchidCheck.rowCount === 0) {
      return null;
    }

    return orchidId;
  }

  if (!scientificName) {
    return null;
  }

  const genusId = await ensureGenus(client, genusName);

  const upsertOrchid = await client.query(
    `INSERT INTO orchids (sci_name, common_name, genus_id)
     VALUES ($1, NULLIF($2, ''), $3)
     ON CONFLICT (sci_name)
     DO UPDATE SET
       common_name = COALESCE(EXCLUDED.common_name, orchids.common_name),
       genus_id = COALESCE(EXCLUDED.genus_id, orchids.genus_id)
     RETURNING orchid_id`,
    [scientificName, commonName, genusId]
  );

  return upsertOrchid.rows[0].orchid_id;
}

router.get('/', async (req, res, next) => {
  try {
    const speciesId = Number(req.query.speciesId);

    const where = [];
    const params = [];

    if (Number.isInteger(speciesId) && speciesId > 0) {
      params.push(speciesId);
      where.push(`ol.orchid_id = $${params.length}`);
    }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';

    const result = await query(
      `SELECT
        ol.orchid_location_id AS id,
        ol.orchid_id AS "speciesId",
        o.sci_name AS "scientificName",
        o.common_name AS "commonName",
        ST_Y(ol.geom::geometry) AS lat,
        ST_X(ol.geom::geometry) AS lng,
        ol.notes,
        ol.date_recorded AS "observedAt",
        ol.date_recorded AS "createdAt",
        ol.elevation,
        mt.mountain_name AS mountain,
        mu.municipality_name AS municipality,
        pr.province_name AS province
      FROM orchid_location ol
      JOIN orchids o ON o.orchid_id = ol.orchid_id
      LEFT JOIN mountain mt ON mt.mountain_id = ol.mountain_id
      LEFT JOIN municipality mu ON mu.municipality_id = mt.municipality_id
      LEFT JOIN province pr ON pr.province_id = mu.province_id
      ${whereClause}
      ORDER BY ol.date_recorded DESC, ol.orchid_location_id DESC
      LIMIT 500`,
      params
    );

    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

router.get('/near', async (req, res, next) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const radiusMeters = Number(req.query.radiusMeters || 2000);

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ error: 'lat and lng are required numbers.' });
    }

    if (!Number.isFinite(radiusMeters) || radiusMeters <= 0) {
      return res.status(400).json({ error: 'radiusMeters must be > 0.' });
    }

    const result = await query(
      `SELECT
        ol.orchid_location_id AS id,
        ol.orchid_id AS "speciesId",
        o.sci_name AS "scientificName",
        o.common_name AS "commonName",
        ST_Y(ol.geom::geometry) AS lat,
        ST_X(ol.geom::geometry) AS lng,
        ol.notes,
        ol.date_recorded AS "observedAt",
        ST_Distance(
          ol.geom,
          ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
        ) AS "distanceMeters"
      FROM orchid_location ol
      JOIN orchids o ON o.orchid_id = ol.orchid_id
      WHERE ST_DWithin(
        ol.geom,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        $3
      )
      ORDER BY "distanceMeters" ASC
      LIMIT 200`,
      [lng, lat, radiusMeters]
    );

    return res.json(result.rows);
  } catch (error) {
    return next(error);
  }
});

router.get('/geojson', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features', COALESCE(jsonb_agg(feature), '[]'::jsonb)
      ) AS data
      FROM (
        SELECT jsonb_build_object(
          'type', 'Feature',
          'geometry', ST_AsGeoJSON(ol.geom::geometry)::jsonb,
          'properties', jsonb_build_object(
            'id', ol.orchid_location_id,
            'speciesId', ol.orchid_id,
            'scientificName', o.sci_name,
            'commonName', o.common_name,
            'notes', ol.notes,
            'observedAt', ol.date_recorded
          )
        ) AS feature
        FROM orchid_location ol
        JOIN orchids o ON o.orchid_id = ol.orchid_id
        ORDER BY ol.date_recorded DESC
        LIMIT 500
      ) src`
    );

    return res.json(result.rows[0].data);
  } catch (error) {
    return next(error);
  }
});

router.post('/', async (req, res, next) => {
  const speciesId = Number(req.body.speciesId);
  const scientificName = String(req.body.scientificName || '').trim();
  const commonName = String(req.body.commonName || '').trim();
  const genus = String(req.body.genus || '').trim();
  const notes = String(req.body.notes || '').trim();
  const observedAtRaw = String(req.body.observedAt || '').trim();
  const elevationRaw = Number(req.body.elevation);
  const requestedLat = Number(req.body.lat);
  const requestedLng = Number(req.body.lng);
  const lat = Number.isFinite(requestedLat) ? requestedLat : 5.9295;
  const lng = Number.isFinite(requestedLng) ? requestedLng : 125.08;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const resolvedSpeciesId = await resolveOrchidId(
      client,
      speciesId,
      scientificName,
      commonName,
      genus
    );

    if (!resolvedSpeciesId) {
      await client.query('ROLLBACK');
      return res
        .status(400)
        .json({ error: 'Provide a valid speciesId or scientificName.' });
    }

    const observedAt = observedAtRaw || null;
    const elevation = Number.isFinite(elevationRaw) ? elevationRaw : null;

    const inserted = await client.query(
      `INSERT INTO orchid_location (orchid_id, geom, notes, date_recorded, elevation)
       VALUES (
         $1,
         ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
         NULLIF($4, ''),
         COALESCE($5::timestamptz, NOW()),
         $6
       )
       RETURNING
         orchid_location_id AS id,
         orchid_id AS "speciesId",
         ST_Y(geom::geometry) AS lat,
         ST_X(geom::geometry) AS lng,
         notes,
         date_recorded AS "observedAt",
         date_recorded AS "createdAt",
         elevation`,
      [resolvedSpeciesId, lng, lat, notes, observedAt, elevation]
    );

    const species = await client.query(
      `SELECT
        sci_name AS "scientificName",
        common_name AS "commonName"
      FROM orchids
      WHERE orchid_id = $1`,
      [resolvedSpeciesId]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      ...inserted.rows[0],
      scientificName: species.rows[0].scientificName,
      commonName: species.rows[0].commonName,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    return next(error);
  } finally {
    client.release();
  }
});

module.exports = router;
