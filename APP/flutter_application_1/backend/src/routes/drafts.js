const express = require('express');

const { pool } = require('../db');
const {
  isSupabaseStorageConfigured,
  uploadImageToSupabaseStorage,
  deleteImageFromSupabaseStorage,
} = require('../supabaseStorage');

const router = express.Router();

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

function asTrimmedString(value) {
  return String(value || '').trim();
}

function asFiniteNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseContributors(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }

  return raw
    .map((item) => ({
      name: asTrimmedString(item?.name),
      position: asTrimmedString(item?.position),
    }))
    .filter((item) => item.name && item.position);
}

function parseImages(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }

  return raw
    .map((item) => ({
      fileName: asTrimmedString(item?.fileName),
      contentType: asTrimmedString(item?.contentType),
      photoCredit: asTrimmedString(item?.photoCredit),
      base64Data: asTrimmedString(item?.base64Data).replace(/\s+/g, ''),
    }))
    .filter((item) => item.base64Data);
}

function decodeBase64Image(base64Data) {
  const bytes = Buffer.from(base64Data, 'base64');
  return bytes;
}

function buildFloweringSeason(fromMonth, toMonth) {
  const from = asTrimmedString(fromMonth);
  const to = asTrimmedString(toMonth);

  if (from && to) {
    return `${from} to ${to}`;
  }

  return from || to || '';
}

function toNullableInt(value) {
  const parsed = Number.parseInt(String(value || '').trim(), 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function toNullableFloat(value) {
  const parsed = Number(String(value || '').trim());
  return Number.isFinite(parsed) ? parsed : null;
}

async function ensureGenus(client, genusName) {
  const normalized = asTrimmedString(genusName);
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

async function ensureProvince(client, provinceName) {
  const normalized = asTrimmedString(provinceName);
  if (!normalized) {
    return null;
  }

  const result = await client.query(
    `INSERT INTO province (province_name)
     VALUES ($1)
     ON CONFLICT (province_name)
     DO UPDATE SET province_name = EXCLUDED.province_name
     RETURNING province_id`,
    [normalized]
  );

  return result.rows[0].province_id;
}

async function ensureMunicipality(client, provinceId, municipalityName) {
  const normalized = asTrimmedString(municipalityName);
  if (!provinceId || !normalized) {
    return null;
  }

  const result = await client.query(
    `INSERT INTO municipality (province_id, municipality_name)
     VALUES ($1, $2)
     ON CONFLICT (province_id, municipality_name)
     DO UPDATE SET municipality_name = EXCLUDED.municipality_name
     RETURNING municipality_id`,
    [provinceId, normalized]
  );

  return result.rows[0].municipality_id;
}

async function ensureMountain(client, municipalityId, mountainName, longitude, latitude) {
  const normalized = asTrimmedString(mountainName);
  if (!municipalityId || !normalized) {
    return null;
  }

  const result = await client.query(
    `INSERT INTO mountain (municipality_id, mountain_name, geom)
     VALUES (
       $1,
       $2,
       CASE
         WHEN $3::double precision IS NULL OR $4::double precision IS NULL THEN NULL
         ELSE ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography
       END
     )
     ON CONFLICT (municipality_id, mountain_name)
     DO UPDATE SET
       geom = COALESCE(EXCLUDED.geom, mountain.geom)
     RETURNING mountain_id`,
    [municipalityId, normalized, longitude, latitude]
  );

  return result.rows[0].mountain_id;
}

function buildSightingNotes({ payload, contributors, uploadedImages }) {
  const metadata = {
    draftId: asTrimmedString(payload.draftId),
    family: asTrimmedString(payload.family),
    genus: asTrimmedString(payload.genus),
    endemicToPhilippines: payload.endemicToPhilippines === true,
    leafType: asTrimmedString(payload.leafType),
    flowerColor: asTrimmedString(payload.flowerColor),
    floweringFromMonth: asTrimmedString(payload.floweringFromMonth),
    floweringToMonth: asTrimmedString(payload.floweringToMonth),
    numberLocated: asTrimmedString(payload.numberLocated),
    ethnonotanicalImportance: asTrimmedString(payload.ethnonotanicalImportance),
    aestheticAppeal: asTrimmedString(payload.aestheticAppeal),
    cultivation: asTrimmedString(payload.cultivation),
    rarity: asTrimmedString(payload.rarity),
    culturalImportance: asTrimmedString(payload.culturalImportance),
    province: asTrimmedString(payload.province),
    municipality: asTrimmedString(payload.municipality),
    mountain: asTrimmedString(payload.mountain),
    altitude: asTrimmedString(payload.altitude),
    elevation: asTrimmedString(payload.elevation),
    habitatType: asTrimmedString(payload.habitatType),
    microHabitat: asTrimmedString(payload.microHabitat),
    contributors,
    images: uploadedImages.map((image) => ({
      imageUrl: image.imageUrl,
      photoCredit: image.photoCredit,
    })),
  };

  return JSON.stringify(metadata);
}

router.post('/submit', async (req, res, next) => {
  const scientificName = asTrimmedString(req.body.scientificName);
  const commonName = asTrimmedString(req.body.commonName);
  const latitude = asFiniteNumber(req.body.latitude);
  const longitude = asFiniteNumber(req.body.longitude);
  const resolvedLatitude = latitude ?? 5.9295;
  const resolvedLongitude = longitude ?? 125.08;
  const observedAtRaw = asTrimmedString(req.body.observedAt);
  const contributors = parseContributors(req.body.contributors);
  const images = parseImages(req.body.images);

  if (!scientificName) {
    return res.status(400).json({ error: 'scientificName is required.' });
  }

  if (!commonName) {
    return res.status(400).json({ error: 'commonName is required.' });
  }

  if (images.length === 0) {
    return res.status(400).json({ error: 'At least one image is required.' });
  }

  for (const image of images) {
    if (!image.photoCredit) {
      return res.status(400).json({
        error: 'photoCredit is required for every image.',
      });
    }
  }

  if (contributors.length === 0) {
    return res.status(400).json({
      error: 'At least one contributor with name and position is required.',
    });
  }

  if (!isSupabaseStorageConfigured()) {
    return res.status(500).json({
      error:
        'Supabase Storage is not configured. Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SUPABASE_STORAGE_BUCKET.',
    });
  }

  const uploadedObjects = [];
  const uploadedImages = [];

  try {
    for (let index = 0; index < images.length; index += 1) {
      const image = images[index];
      const imageBytes = decodeBase64Image(image.base64Data);

      if (!imageBytes || imageBytes.length === 0) {
        throw new Error(`Image ${index + 1} has invalid base64 data.`);
      }

      if (imageBytes.length > MAX_IMAGE_BYTES) {
        throw new Error(
          `Image ${index + 1} exceeds the ${Math.round(MAX_IMAGE_BYTES / (1024 * 1024))} MB limit.`
        );
      }

      const uploadResult = await uploadImageToSupabaseStorage({
        imageBytes,
        fileName: image.fileName,
        contentType: image.contentType,
        scientificName,
        draftId: asTrimmedString(req.body.draftId) || 'draft',
        imageIndex: index,
      });

      uploadedObjects.push(uploadResult.objectPath);
      uploadedImages.push({
        imageUrl: uploadResult.publicUrl,
        photoCredit: image.photoCredit,
      });
    }
  } catch (error) {
    await Promise.all(uploadedObjects.map((path) => deleteImageFromSupabaseStorage(path)));
    return res.status(400).json({ error: error.message || 'Image upload failed.' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const genusId = await ensureGenus(client, req.body.genus);
    const speciesResult = await client.query(
      `INSERT INTO orchids (sci_name, common_name, genus_id)
       VALUES ($1, NULLIF($2, ''), $3)
       ON CONFLICT (sci_name)
       DO UPDATE SET
         common_name = COALESCE(EXCLUDED.common_name, orchids.common_name),
         genus_id = COALESCE(EXCLUDED.genus_id, orchids.genus_id)
       RETURNING
         orchid_id AS id,
         sci_name AS "scientificName",
         common_name AS "commonName"`,
      [scientificName, commonName, genusId]
    );

    const species = speciesResult.rows[0];
    const submittedAt = observedAtRaw || null;

    await client.query(
      `INSERT INTO morphological_characteristics (
        orchid_id,
        leaf_type,
        flower_color,
        flowering_season
      )
      VALUES ($1, NULLIF($2, ''), NULLIF($3, ''), NULLIF($4, ''))
      ON CONFLICT (orchid_id)
      DO UPDATE SET
        leaf_type = COALESCE(EXCLUDED.leaf_type, morphological_characteristics.leaf_type),
        flower_color = COALESCE(EXCLUDED.flower_color, morphological_characteristics.flower_color),
        flowering_season = COALESCE(EXCLUDED.flowering_season, morphological_characteristics.flowering_season)`,
      [
        species.id,
        asTrimmedString(req.body.leafType),
        asTrimmedString(req.body.flowerColor),
        buildFloweringSeason(req.body.floweringFromMonth, req.body.floweringToMonth),
      ]
    );

    const horticulturalSummary = [
      `aesthetic:${asTrimmedString(req.body.aestheticAppeal)}`,
      `cultivation:${asTrimmedString(req.body.cultivation)}`,
      `rarity:${asTrimmedString(req.body.rarity)}`,
      `cultural:${asTrimmedString(req.body.culturalImportance)}`,
    ]
      .filter((part) => !part.endsWith(':'))
      .join(' | ');

    const validitySummary = [
      `endemicToPhilippines:${req.body.endemicToPhilippines === true}`,
      `numberLocated:${asTrimmedString(req.body.numberLocated)}`,
    ].join(' | ');

    await client.query(
      `INSERT INTO species_value (
        orchid_id,
        ethnobotanical_value,
        horticultural_value,
        validity
      )
      VALUES ($1, NULLIF($2, ''), NULLIF($3, ''), NULLIF($4, ''))
      ON CONFLICT (orchid_id)
      DO UPDATE SET
        ethnobotanical_value = COALESCE(EXCLUDED.ethnobotanical_value, species_value.ethnobotanical_value),
        horticultural_value = COALESCE(EXCLUDED.horticultural_value, species_value.horticultural_value),
        validity = COALESCE(EXCLUDED.validity, species_value.validity)`,
      [
        species.id,
        asTrimmedString(req.body.ethnonotanicalImportance),
        horticulturalSummary,
        validitySummary,
      ]
    );

    const submissionRows = [];
    for (const image of uploadedImages) {
      const submissionResult = await client.query(
        `INSERT INTO picture (orchid_id, file_url, file_type, file_size, status, photo_credit, date_uploaded)
         VALUES (
           $1,
           $2,
           'image/jpeg',
           NULL,
           'pending',
           NULLIF($3, ''),
           COALESCE($4::timestamptz, NOW())
         )
         RETURNING
           picture_id AS id,
           orchid_id AS "speciesId",
           file_url AS "imageUrl",
           status,
           photo_credit AS "photoCredit",
           date_uploaded AS "uploadedAt"`,
        [species.id, image.imageUrl, image.photoCredit, submittedAt]
      );

      submissionRows.push({
        ...submissionResult.rows[0],
        photoCredit: image.photoCredit,
      });
    }

    const notes = buildSightingNotes({
      payload: req.body,
      contributors,
      uploadedImages,
    });

    const provinceId = await ensureProvince(client, req.body.province);
    const municipalityId = await ensureMunicipality(
      client,
      provinceId,
      req.body.municipality
    );
    const mountainId = await ensureMountain(
      client,
      municipalityId,
      req.body.mountain,
      resolvedLongitude,
      resolvedLatitude
    );

    const elevation = toNullableFloat(req.body.elevation) ?? toNullableFloat(req.body.altitude);

    const sightingResult = await client.query(
      `INSERT INTO orchid_location (orchid_id, mountain_id, geom, notes, date_recorded, elevation)
       VALUES (
         $1,
         $2,
         ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
         NULLIF($5, ''),
         COALESCE($6::timestamptz, NOW()),
         $7
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
      [
        species.id,
        mountainId,
        resolvedLongitude,
        resolvedLatitude,
        notes,
        submittedAt,
        elevation,
      ]
    );

    const orchidLocationId = sightingResult.rows[0].id;

    await client.query(
      `INSERT INTO habitat_information (
        orchid_location_id,
        altitude,
        vertical_distribution,
        habitat_type,
        micro_habitat
      )
      VALUES ($1, NULLIF($2, ''), NULLIF($3, ''), NULLIF($4, ''), NULLIF($5, ''))
      ON CONFLICT (orchid_location_id)
      DO UPDATE SET
        altitude = COALESCE(EXCLUDED.altitude, habitat_information.altitude),
        vertical_distribution = COALESCE(EXCLUDED.vertical_distribution, habitat_information.vertical_distribution),
        habitat_type = COALESCE(EXCLUDED.habitat_type, habitat_information.habitat_type),
        micro_habitat = COALESCE(EXCLUDED.micro_habitat, habitat_information.micro_habitat)`,
      [
        orchidLocationId,
        asTrimmedString(req.body.altitude),
        asTrimmedString(req.body.elevation),
        asTrimmedString(req.body.habitatType),
        asTrimmedString(req.body.microHabitat),
      ]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      scientificName: species.scientificName,
      commonName: species.commonName,
      speciesId: species.id,
      sighting: sightingResult.rows[0],
      submissions: submissionRows,
      submissionCount: submissionRows.length,
      imageUrls: submissionRows.map((item) => item.imageUrl),
    });
  } catch (error) {
    await client.query('ROLLBACK');
    await Promise.all(uploadedObjects.map((path) => deleteImageFromSupabaseStorage(path)));
    return next(error);
  } finally {
    client.release();
  }
});

module.exports = router;
