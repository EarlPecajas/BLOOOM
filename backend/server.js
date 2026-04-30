require("dotenv").config();

const path = require("path");
const crypto = require("crypto");
const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const multer = require("multer");
const { Pool } = require("pg");
const { getPgConfig } = require("./db");
const { uploadFile } = require("./storage");

const app = express();
const port = process.env.PORT || 3000;
const frontendPath = path.join(__dirname, "..", "frontend");

const supabaseEnabled = process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY;

const submissionUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype || (!file.mimetype.startsWith("image/") && !file.mimetype.startsWith("video/"))) {
      cb(new Error("Only image or video files are allowed."));
      return;
    }
    if (file.mimetype.startsWith("image/") && file.size > 5 * 1024 * 1024) {
      cb(new Error("Image file size must be 5MB or less."));
      return;
    }
    cb(null, true);
  }
});

async function handleSubmissionMediaUpload(req, res, next) {
  submissionUpload.any()(req, res, async (error) => {
    if (error) {
      if (error instanceof multer.MulterError) {
        if (error.code === "LIMIT_FILE_SIZE") {
          res.status(400).json({ message: "Image file size must be 5MB or less." });
          return;
        }
        res.status(400).json({ message: error.message || "Media upload failed." });
        return;
      }
      res.status(400).json({ message: error.message || "Media upload failed." });
      return;
    }

    if (!supabaseEnabled || !req.files) {
      next();
      return;
    }

    try {
      const filesToUpload = Array.isArray(req.files) ? req.files : Object.values(req.files).flat();
      const uploadedMetadata = {};

      for (const file of filesToUpload) {
        const extension = path.extname(file.originalname || "").toLowerCase();
        const safeExt = extension || ".jpg";
        const token = crypto.randomBytes(8).toString("hex");
        const fileName = `${Date.now()}-${token}${safeExt}`;
        const filePath = `submissions/${fileName}`;

        try {
          const publicUrl = await uploadFile("bloom-uploads", filePath, file.buffer, file.mimetype);
          const fieldName = file.fieldname;
          if (!uploadedMetadata[fieldName]) {
            uploadedMetadata[fieldName] = [];
          }
          uploadedMetadata[fieldName].push({ url: publicUrl, originalName: file.originalname });
        } catch (uploadError) {
          console.error(`Failed to upload ${file.originalname}:`, uploadError.message);
          res.status(500).json({ message: `Failed to upload ${file.originalname}`, error: uploadError.message });
          return;
        }
      }

      req.uploadedFiles = uploadedMetadata;
      next();
    } catch (err) {
      console.error("Upload handling error:", err.message);
      res.status(500).json({ message: "Media upload failed", error: err.message });
    }
  });
}

const pool = new Pool({
  ...getPgConfig()
});

app.use(cors());
app.use(express.json());
app.use(express.static(frontendPath));

app.get("/api/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, database: "connected" });
  } catch (error) {
    res.status(500).json({ ok: false, message: "Database connection failed", error: error.message });
  }
});

app.post("/api/register", async (req, res) => {
  const { firstName, lastName, email, birthDate, phone, password } = req.body;

  if (!firstName || !lastName || !email || !password) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const passwordHash = await bcrypt.hash(password, 10);
    let primaryInsertCompleted = false;

    try {
      const existingAccount = await pool.query("SELECT account_id FROM account WHERE email = $1", [email]);
      if (existingAccount.rows.length > 0) {
        return res.status(409).json({ message: "Email already registered" });
      }

      const client = await pool.connect();
      try {
        await client.query("BEGIN");

        const newUser = await client.query(
          `INSERT INTO "user" (first_name, last_name)
           VALUES ($1, $2)
           RETURNING user_id`,
          [firstName, lastName]
        );

        await client.query(
          `INSERT INTO account (user_id, email, username, password, account_type_id)
           VALUES (
             $1,
             $2,
             $3,
             $4,
             (SELECT account_type_id FROM account_type WHERE lower(account_desc) = 'researcher' LIMIT 1)
           )`,
          [newUser.rows[0].user_id, email, email, passwordHash]
        );

        await client.query("COMMIT");
        primaryInsertCompleted = true;
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      } finally {
        client.release();
      }
    } catch {
      // Fallback for legacy schema.
      const existingUser = await pool.query("SELECT id FROM users WHERE email = $1", [email]);
      if (existingUser.rows.length > 0) {
        return res.status(409).json({ message: "Email already registered" });
      }

      await pool.query(
        `INSERT INTO users (first_name, last_name, email, birth_date, phone, password_hash)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [firstName, lastName, email, birthDate || null, phone || null, passwordHash]
      );
    }

    // Mirror successful account-based registrations into legacy users table for compatibility.
    if (primaryInsertCompleted) {
      try {
        await pool.query(
          `INSERT INTO users (first_name, last_name, email, birth_date, phone, password_hash)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (email)
           DO UPDATE SET
             first_name = EXCLUDED.first_name,
             last_name = EXCLUDED.last_name,
             birth_date = EXCLUDED.birth_date,
             phone = EXCLUDED.phone`,
          [firstName, lastName, email, birthDate || null, phone || null, passwordHash]
        );
      } catch {
        // Ignore if legacy users table is unavailable in this schema.
      }
    }

    return res.status(201).json({ message: "Registration successful" });
  } catch (error) {
    return res.status(500).json({ message: "Failed to register user", error: error.message });
  }
});

app.post("/api/login", async (req, res) => {
  const { email, password } = req.body;
  const identifier = (email || "").trim();

  if (!identifier || !password) {
    return res.status(400).json({ message: "Email and password are required" });
  }

  try {
    let user;

    try {
      const accountResult = await pool.query(
        `SELECT
           u.user_id AS id,
           u.first_name,
           u.last_name,
           a.email,
           a.password AS password_hash,
           a.username,
           coalesce(at.account_desc, 'user') AS role
         FROM account a
         JOIN "user" u ON u.user_id = a.user_id
         LEFT JOIN account_type at ON at.account_type_id = a.account_type_id
         WHERE lower(a.email) = lower($1)
            OR lower(coalesce(a.username, '')) = lower($1)`,
        [identifier]
      );

      if (accountResult.rows.length > 0) {
        user = accountResult.rows[0];
      }
    } catch {
      // Fallback handled below.
    }

    if (!user) {
      const legacyResult = await pool.query(
        "SELECT id, first_name, last_name, email, password_hash FROM users WHERE email = $1",
        [identifier]
      );

      if (legacyResult.rows.length === 0) {
        return res.status(401).json({ message: "Invalid credentials" });
      }

      user = legacyResult.rows[0];
    }

    const matches = await bcrypt.compare(password, user.password_hash);

    if (!matches) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    return res.json({
      message: "Login successful",
      user: {
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        username: user.username || user.email,
        role: user.role || "user"
      }
    });
  } catch (error) {
    return res.status(500).json({ message: "Login failed", error: error.message });
  }
});

app.get("/api/orchids", async (_req, res) => {
  try {
    const erdResult = await pool.query(
      `SELECT
         o.orchid_id AS id,
         o.sci_name AS name,
         coalesce(g.genus_name, to_jsonb(s)->>'genus', to_jsonb(s)->>'genus_name') AS genus,
         coalesce(o.common_name, to_jsonb(s)->>'common_name', to_jsonb(s)->>'common') AS common_name,
         coalesce(o.endemicity, to_jsonb(s)->>'endemicity') AS endemicity,
         NULL::text AS ethnobotanical,
         NULL::text AS horticulture_value,
         NULL::text AS cultural_importance,
         p.file_path AS image_url
       FROM orchids o
       JOIN genus g ON g.genus_id = o.genus_id
       LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
       LEFT JOIN specie_value sv ON sv.specie_val_id = b.specie_val_id
       LEFT JOIN picture p ON p.picture_id = b.picture_id
       LEFT JOIN species s ON lower(coalesce(
         to_jsonb(s)->>'scientific_name',
         to_jsonb(s)->>'sci_name',
         to_jsonb(s)->>'species_name',
         to_jsonb(s)->>'name'
       )) = lower(o.sci_name)
       ORDER BY o.sci_name ASC`
    );

    return res.json(erdResult.rows);
  } catch (error) {
    try {
      // Fallback for older schema used during initial setup.
      const fallback = await pool.query(
        `SELECT
           id,
           name,
           genus,
           image_url,
           NULL::text AS common_name,
           NULL::text AS endemicity,
           NULL::text AS ethnobotanical,
           NULL::text AS horticulture_value,
           NULL::text AS cultural_importance
         FROM orchids
         ORDER BY name ASC`
      );
      return res.json(fallback.rows);
    } catch {
      return res.status(500).json({ message: "Failed to fetch orchids", error: error.message });
    }
  }
});

app.get("/api/conservation-summary", async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         CASE
           WHEN lower(coalesce(cs.conservation_status, '')) IN ('critically endangered', 'critically_endangered') THEN 'critically_endangered'
           WHEN lower(coalesce(cs.conservation_status, '')) IN ('endangered') THEN 'endangered'
           WHEN lower(coalesce(cs.conservation_status, '')) IN ('vulnerable') THEN 'vulnerable'
           WHEN lower(coalesce(cs.conservation_status, '')) IN ('least concern', 'least_concern') THEN 'least_concern'
           ELSE 'unassigned'
         END AS status_key,
         COUNT(*)::int AS count
       FROM orchids o
       LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
       LEFT JOIN conservation_status cs ON cs.conservation_id = b.conservation_id
       GROUP BY status_key`
    );

    const summary = {
      critically_endangered: 0,
      endangered: 0,
      vulnerable: 0,
      least_concern: 0,
      unassigned: 0
    };

    for (const row of result.rows) {
      summary[row.status_key] = row.count;
    }

    return res.json(summary);
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch conservation summary", error: error.message });
  }
});

app.get("/api/conservation-list/:statusKey", async (req, res) => {
  const { statusKey } = req.params;
  const allowed = new Set([
    "critically_endangered",
    "endangered",
    "vulnerable",
    "least_concern",
    "unassigned"
  ]);

  if (!allowed.has(statusKey)) {
    return res.status(400).json({ message: "Invalid conservation status" });
  }

  try {
    const result = await pool.query(
      `SELECT
         o.sci_name AS name,
         g.genus_name AS genus,
         coalesce(cs.conservation_status, 'Unassigned') AS conservation_status
       FROM orchids o
       JOIN genus g ON g.genus_id = o.genus_id
       LEFT JOIN biogeography b ON b.orchid_id = o.orchid_id
       LEFT JOIN conservation_status cs ON cs.conservation_id = b.conservation_id
       WHERE (
         ($1 = 'critically_endangered' AND lower(coalesce(cs.conservation_status, '')) IN ('critically endangered', 'critically_endangered')) OR
         ($1 = 'endangered' AND lower(coalesce(cs.conservation_status, '')) = 'endangered') OR
         ($1 = 'vulnerable' AND lower(coalesce(cs.conservation_status, '')) = 'vulnerable') OR
         ($1 = 'least_concern' AND lower(coalesce(cs.conservation_status, '')) IN ('least concern', 'least_concern')) OR
         ($1 = 'unassigned' AND coalesce(cs.conservation_status, '') = '')
       )
       ORDER BY o.sci_name ASC`,
      [statusKey]
    );

    return res.json(result.rows);
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch conservation list", error: error.message });
  }
});

function toJsonArray(value, maxItems = null) {
  if (!value) {
    return [];
  }

  let parsed = [];
  if (Array.isArray(value)) {
    parsed = value;
  } else if (typeof value === "string") {
    try {
      const asJson = JSON.parse(value);
      parsed = Array.isArray(asJson) ? asJson : [value];
    } catch {
      parsed = String(value)
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
    }
  } else {
    parsed = [String(value)];
  }

  const normalized = parsed
    .map((item) => String(item || "").trim())
    .filter(Boolean);

  if (maxItems && normalized.length > maxItems) {
    return normalized.slice(0, maxItems);
  }
  return normalized;
}

function toNullableNumber(value) {
  if (value === null || value === undefined || String(value).trim() === "") {
    return null;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function toNullableInteger(value) {
  const parsed = toNullableNumber(value);
  return parsed === null ? null : Math.trunc(parsed);
}

function toNullableBoolean(value) {
  if (value === null || value === undefined || String(value).trim() === "") {
    return null;
  }
  const normalized = String(value).trim().toLowerCase();
  if (["yes", "true", "1"].includes(normalized)) return true;
  if (["no", "false", "0"].includes(normalized)) return false;
  return null;
}

function getUploadedFilePaths(req, fieldName) {
  // If using Supabase Storage, pull from uploadedFiles metadata
  if (supabaseEnabled && req.uploadedFiles && req.uploadedFiles[fieldName]) {
    return req.uploadedFiles[fieldName].map((f) => f.url);
  }

  // Fallback to local files (for backward compatibility or if Supabase is disabled)
  if (!req.files) return [];

  // If multer produced an object keyed by field name (fields())
  if (!Array.isArray(req.files) && typeof req.files === 'object') {
    const files = req.files[fieldName];
    if (!files || files.length === 0) return [];
    return files.map((f) => `/uploads/${f.filename}`);
  }

  // If multer produced an array of files (any())
  if (Array.isArray(req.files)) {
    return req.files
      .filter((f) => String(f.fieldname || '') === String(fieldName))
      .map((f) => `/uploads/${f.filename}`);
  }

  return [];
}

app.get("/api/submissions", async (req, res) => {
  const search = String(req.query.search || "").trim();
  const pattern = `%${search}%`;
  const ownOnly = ["1", "true", "yes"].includes(String(req.query.ownOnly || "").trim().toLowerCase());
  const userIdRaw = Number.parseInt(String(req.query.userId || ""), 10);
  const userId = Number.isInteger(userIdRaw) ? userIdRaw : null;
  const researcherIdentity = String(req.query.email || "").trim();
  // DENR access requires a server-side token. Accept either Authorization: Bearer <token>
  // or a custom header `x-denr-token`.
  const denrToken = process.env.DENR_TOKEN || '';
  let isDenr = false;
  try {
    const auth = String(req.headers.authorization || '').trim();
    if (auth.toLowerCase().startsWith('bearer ')) {
      const token = auth.slice(7).trim();
      if (token && denrToken && token === denrToken) isDenr = true;
    }
    const headerToken = String(req.headers['x-denr-token'] || '').trim();
    if (!isDenr && headerToken && denrToken && headerToken === denrToken) isDenr = true;
  } catch (e) {
    isDenr = false;
  }

  try {
    const result = await pool.query(
      `SELECT
         s.sighting_id AS id,
         s.entry_id,
         coalesce(nullif(trim(s.researcher_name), ''), nullif(trim(concat_ws(' ', u.first_name, u.last_name)), ''), 'Unknown Researcher') AS researcher,
         s.scientific_name AS species,
         NULL::text AS family,
         NULL::text AS genus,
         coalesce((s.common_names->>0), '-') AS common_name,
         s.common_names,
         s.identification_confidence,
         s.observation_date,
         s.observation_time,
         s.collection_method,
         s.observation_type,
         s.voucher_collected,
         s.mountain_name,
         s.specific_site_zone,
         s.specific_site_other,
         s.latitude,
         s.longitude,
         s.elevation_meters,
         s.habitat_type,
         s.microhabitat,
         s.growth_substrate,
         s.host_tree_species,
         s.host_tree_dbh_cm,
         s.canopy_cover_percent,
         s.light_exposure,
         s.soil_type,
         s.nearby_water_source,
         s.plant_height_cm,
         s.pseudobulb_present,
         s.stem_length_cm,
         s.root_length_cm,
         s.leaf_count,
         s.leaf_shape,
         s.leaf_shape_other,
         s.leaf_length_cm,
         s.leaf_width_cm,
         s.leaf_textures,
         s.leaf_arrangement,
         s.flower_color,
         s.flower_count,
         s.flower_diameter_cm,
         s.inflorescence_type,
         s.petal_characteristics,
         s.sepal_characteristics,
         s.labellum_lip_description,
         s.fragrance,
         s.blooming_stage,
         s.fruit_present,
         s.fruit_type,
         s.seed_capsule_condition,
         s.life_stage,
         s.phenology,
         s.population_count,
         s.population_status,
         s.threat_level,
         s.threat_types,
         coalesce(s.habitat_type, '-') AS habitat,
         coalesce(s.population_status, '-') AS endemicity,
         coalesce(s.threat_level, 'Unassigned') AS conservation_status,
         coalesce(s.researcher_notes, '-') AS ethnobotanical,
         coalesce(s.institution, '-') AS horticulture_value,
         coalesce(s.unusual_observations, '-') AS cultural_importance,
         coalesce(s.whole_plant_photo_path, '[]'::jsonb) AS whole_plant_photos,
         coalesce(s.mountain_name, 'Mt. Busa') ||
           coalesce(', ' || s.specific_site_zone, '') AS location,
         s.user_id,
         coalesce(s.researcher_email, a.email, '') AS researcher_email,
         to_char(coalesce(s.observation_date, s.created_at::date), 'YYYY-MM-DD') AS submission_date,
         coalesce(nullif(lower(s.review_status), ''), 'pending') AS review_status,
         s.team_members,
         coalesce(s.researcher_notes, '') AS researcher_notes,
         coalesce(s.unusual_observations, '') AS unusual_observations,
         coalesce(s.closeup_flower_photo_path, '[]'::jsonb) AS closeup_flower_photos,
         coalesce(s.habitat_photo_path, '[]'::jsonb) AS habitat_photos,
         coalesce(s.video_path, '[]'::jsonb) AS video_files
       FROM species_sightings s
       LEFT JOIN "user" u ON u.user_id = s.user_id
       LEFT JOIN account a ON a.user_id = u.user_id
       WHERE (
         $1 = '%%' OR
         s.scientific_name ILIKE $1 OR
         coalesce(s.researcher_name, '') ILIKE $1 OR
         coalesce(s.researcher_email, '') ILIKE $1 OR
         coalesce(s.review_status, '') ILIKE $1 OR
         coalesce(s.mountain_name, '') ILIKE $1 OR
         coalesce(s.specific_site_zone, '') ILIKE $1 OR
         coalesce((s.common_names->>0), '') ILIKE $1 OR
         coalesce(s.threat_level, '') ILIKE $1
       )
       AND (
         NOT $2::boolean OR
         ($3::int IS NOT NULL AND s.user_id = $3) OR
         ($4::text <> '' AND lower(coalesce(s.researcher_email, '')) = lower($4))
       )
       ORDER BY s.created_at DESC, s.sighting_id DESC`,
      [pattern, ownOnly, userId, researcherIdentity]
    );

    let rows = result.rows || [];

    // If the request is not from the submitting user, not a researcher identity lookup, and not DENR,
    // hide sensitive fields (media and researcher-only notes)
    if (!ownOnly && !researcherIdentity && !isDenr) {
      rows = rows.map((r) => {
        const copy = Object.assign({}, r);
        copy.whole_plant_photos = [];
        copy.closeup_flower_photos = [];
        copy.habitat_photos = [];
        copy.video_files = [];
        copy.researcher_notes = '';
        copy.unusual_observations = '';
        copy.researcher_email = '';
        return copy;
      });
    }

    return res.json(rows);
  } catch (error) {
    return res.status(500).json({ message: "Failed to fetch submissions", error: error.message });
  }
});

app.post("/api/submissions", handleSubmissionMediaUpload, async (req, res) => {
  const body = req.body || {};
  const scientificName = String(body.scientificName || "").trim();
  const latitude = toNullableNumber(body.latitude);
  const longitude = toNullableNumber(body.longitude);

  if (!scientificName) {
    return res.status(400).json({ message: "Scientific name is required (or use IDK)." });
  }

  if (latitude === null || longitude === null) {
    return res.status(400).json({ message: "GPS latitude and longitude are required." });
  }

  let resolvedUserId = Number.isInteger(Number(body.userId)) ? Number(body.userId) : null;
  const researcherIdentity = String(body.email || "").trim();

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    if (!resolvedUserId && researcherIdentity) {
      const userLookup = await client.query(
        `SELECT u.user_id
         FROM account a
         JOIN "user" u ON u.user_id = a.user_id
         WHERE lower(a.email) = lower($1)
            OR lower(coalesce(a.username, '')) = lower($1)
         LIMIT 1`,
        [researcherIdentity]
      );
      if (userLookup.rows.length > 0) {
        resolvedUserId = Number(userLookup.rows[0].user_id);
      }
    }

    if (!resolvedUserId) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Could not resolve researcher account" });
    }

    const entryId = `SIGHT-${Date.now()}-${crypto.randomBytes(3).toString("hex").toUpperCase()}`;

    const commonNames = toJsonArray(body.commonNames, 5);
    const leafTextures = toJsonArray(body.leafTextures, null);
    const threatTypes = toJsonArray(body.threatTypes, null);

    const insertResult = await client.query(
      `INSERT INTO species_sightings (
         entry_id,
         user_id,
         researcher_email,
         researcher_name,
         scientific_name,
         common_names,
         identification_confidence,
         observation_date,
         observation_time,
         collection_method,
         observation_type,
         voucher_collected,
         mountain_name,
         specific_site_zone,
         specific_site_other,
         latitude,
         longitude,
         elevation_meters,
         habitat_type,
         microhabitat,
         growth_substrate,
         host_tree_species,
         host_tree_dbh_cm,
         canopy_cover_percent,
         light_exposure,
         soil_type,
         nearby_water_source,
         plant_height_cm,
         pseudobulb_present,
         stem_length_cm,
         root_length_cm,
         leaf_count,
         leaf_shape,
         leaf_shape_other,
         leaf_length_cm,
         leaf_width_cm,
         leaf_textures,
         leaf_arrangement,
         flower_color,
         flower_count,
         flower_diameter_cm,
         inflorescence_type,
         petal_characteristics,
         sepal_characteristics,
         labellum_lip_description,
         fragrance,
         blooming_stage,
         fruit_present,
         fruit_type,
         seed_capsule_condition,
         life_stage,
         phenology,
         population_count,
         population_status,
         threat_level,
         threat_types,
         whole_plant_photo_path,
         closeup_flower_photo_path,
         habitat_photo_path,
         photo_3d_path,
         video_path,
         institution,
         team_members,
         researcher_notes,
         unusual_observations,
         review_status
       ) VALUES (
         $1,$2,$3,$4,$5,$6::jsonb,$7,$8,$9,$10,$11,$12,
         $13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,
         $28,$29,$30,$31,$32,$33,$34,$35,$36,$37::jsonb,$38,
         $39,$40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$50,
         $51,$52,$53,$54,$55,$56::jsonb,$57,$58,$59,$60,$61,
         $62,$63,$64,$65,'pending'
       )
       RETURNING sighting_id, entry_id, scientific_name, review_status`,
      [
        entryId,
        resolvedUserId,
        researcherIdentity || null,
        String(body.headObserver || "").trim() || null,
        scientificName,
        JSON.stringify(commonNames),
        String(body.identificationConfidence || "Unidentified").trim() || "Unidentified",
        String(body.observationDate || "").trim() || null,
        String(body.observationTime || "").trim() || null,
        String(body.collectionMethod || "").trim() || null,
        String(body.observationType || "").trim() || null,
        toNullableBoolean(body.voucherCollected),
        "Mt. Busa",
        String(body.specificSiteZone || "").trim() || null,
        String(body.specificSiteOther || "").trim() || null,
        latitude,
        longitude,
        toNullableNumber(body.elevation),
        String(body.habitatType || "").trim() || null,
        String(body.microhabitat || "").trim() || null,
        String(body.growthSubstrate || "").trim() || null,
        String(body.hostTreeSpecies || "").trim() || null,
        toNullableNumber(body.hostTreeDbh),
        toNullableNumber(body.canopyCover),
        String(body.lightExposure || "").trim() || null,
        String(body.soilType || "").trim() || null,
        String(body.nearbyWaterSource || "").trim() || null,
        toNullableNumber(body.plantHeight),
        toNullableBoolean(body.pseudobulbPresent),
        toNullableNumber(body.stemLength),
        toNullableNumber(body.rootLength),
        toNullableInteger(body.leafCount),
        String(body.leafShape || "").trim() || null,
        String(body.leafShapeOther || "").trim() || null,
        toNullableNumber(body.leafLength),
        toNullableNumber(body.leafWidth),
        JSON.stringify(leafTextures),
        String(body.leafArrangement || "").trim() || null,
        String(body.flowerColor || "").trim() || null,
        toNullableInteger(body.flowerCount),
        toNullableNumber(body.flowerDiameter),
        String(body.inflorescenceType || "").trim() || null,
        String(body.petalCharacteristics || "").trim() || null,
        String(body.sepalCharacteristics || "").trim() || null,
        String(body.labellumDescription || "").trim() || null,
        String(body.fragrance || "").trim() || null,
        String(body.bloomingStage || "").trim() || null,
        toNullableBoolean(body.fruitPresent),
        String(body.fruitType || "").trim() || null,
        String(body.seedCapsuleCondition || "").trim() || null,
        String(body.lifeStage || "").trim() || null,
        String(body.phenology || "").trim() || null,
        toNullableInteger(body.populationCount),
        String(body.populationStatus || "").trim() || null,
        String(body.threatLevel || "").trim() || null,
        JSON.stringify(threatTypes),
        JSON.stringify(getUploadedFilePaths(req, "wholePlantPhoto")),
        JSON.stringify(getUploadedFilePaths(req, "closeupFlowerPhoto")),
        JSON.stringify(getUploadedFilePaths(req, "habitatPhoto")),
        JSON.stringify(getUploadedFilePaths(req, "photo3d")),
        JSON.stringify(getUploadedFilePaths(req, "video")),
        String(body.institution || "").trim() || null,
        String(body.teamMembers || "").trim() || null,
        String(body.researcherNotes || "").trim() || null,
        String(body.unusualObservations || "").trim() || null
      ]
    );

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Submission created successfully",
      submission: {
        id: insertResult.rows[0].sighting_id,
        entry_id: insertResult.rows[0].entry_id,
        species: insertResult.rows[0].scientific_name,
        review_status: insertResult.rows[0].review_status
      }
    });
  } catch (error) {
    await client.query("ROLLBACK");
    if (error && error.code === "23505") {
      return res.status(409).json({ message: "A submission with this entry ID already exists. Please submit again." });
    }
    return res.status(500).json({ message: "Failed to create submission", error: error.message });
  } finally {
    client.release();
  }
});

app.patch("/api/submissions/:id/status", async (req, res) => {
  const submissionId = Number(req.params.id);
  const status = String(req.body.status || "").trim().toLowerCase();
  const allowedStatuses = new Set(["approved", "rejected", "revision", "pending"]);

  if (!Number.isInteger(submissionId) || submissionId <= 0) {
    return res.status(400).json({ message: "Invalid submission id" });
  }

  if (!allowedStatuses.has(status)) {
    return res.status(400).json({ message: "Invalid submission status" });
  }

  try {
    const result = await pool.query(
      `UPDATE species_sightings
       SET review_status = $1,
           updated_at = NOW()
       WHERE sighting_id = $2
       RETURNING sighting_id, review_status`,
      [status, submissionId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Submission record not found" });
    }

    return res.json({
      message: "Submission status updated",
      submission: {
        id: result.rows[0].sighting_id,
        review_status: result.rows[0].review_status
      }
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to update submission status", error: error.message });
  }
});

app.get("/", (_req, res) => {
  res.redirect("/index.html");
});

app.get("*", (_req, res) => {
  res.sendFile(path.join(frontendPath, "index.html"));
});

app.listen(port, () => {
  console.log(`BLOOM server running at http://localhost:${port}`);
});