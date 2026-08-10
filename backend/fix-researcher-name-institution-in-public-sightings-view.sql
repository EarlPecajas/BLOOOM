-- public_approved_sightings derived researcher_name/institution via
-- species_sightings.user_id -> "user"/affiliation joins, but user_id is
-- never actually populated at submission time (both submit paths hardcode
-- it to null) -- so these two columns always came back blank/null to
-- catalog.html and researcher-dashboard.html's "Submitted By" section.
-- species_sightings.head_observer_name / institution_name are the real,
-- reliably-populated columns the submission form actually writes to (see
-- add-head-observer-to-sightings.sql and add-institution-to-sightings.sql)
-- -- prefer those, falling back to the user/affiliation join only for
-- older rows that predate those columns.
--
-- Already applied directly to the live database. Kept here for reference
-- and reproducibility. Safe to re-run.

BEGIN;

DROP VIEW IF EXISTS public_approved_sightings;

CREATE VIEW public_approved_sightings AS
SELECT
  s.sighting_id                                 AS id,
  s.scientific_name,
  s.common_names,
  s.local_names,
  s.identification_confidence,
  s.observation_date,
  to_char(s.observation_date, 'YYYY-MM')        AS observation_month,
  s.observation_time,
  s.observation_type,
  s.collection_method,
  s.voucher_collected,
  m.mountain_name,
  p.province_name                               AS province,
  mu.municipality_name                          AS municipality,
  s.specific_site_zone,
  s.specific_site_other,
  s.latitude,
  s.longitude,
  s.elevation_meters,
  sh.habitat_type,
  sh.microhabitat,
  sh.host_tree_species,
  sh.host_tree_dbh_cm,
  sh.canopy_cover_percent,
  sh.light_exposure,
  sh.soil_type,
  sm.plant_height_cm,
  sm.pseudobulb_present,
  sm.stem_length_cm,
  sm.root_length_cm,
  sm.leaf_shape,
  sm.leaf_count,
  sm.leaf_length_cm,
  sm.leaf_width_cm,
  sm.leaf_textures,
  sm.leaf_arrangement,
  sm.flower_color,
  sm.flower_count,
  sm.flower_diameter_cm,
  sm.inflorescence_type,
  sm.petal_characteristics,
  sm.sepal_characteristics,
  sm.labellum_lip_description,
  sm.fragrance,
  sm.flowering_season,
  sm.blooming_stage,
  sm.fruit_present,
  sm.fruit_type,
  sm.seed_capsule_condition,
  sm.life_stage,
  sm.phenology,
  sm.population_count,
  sc.population_status,
  sc.threat_level,
  coalesce(sc.threat_level, '')                 AS threat_level_generalized,
  s.endemic_to_philippines,
  sh.growth_substrate,
  sh.nearby_water_source,
  s.researcher_notes,
  s.related_study,
  NULL::text                                    AS educational_notes,
  'Location hidden for conservation'::text      AS location_visibility_note,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', pic.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture pic ON pic.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'whole_plant'
  )                                             AS whole_plant_photo_path,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', pic.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture pic ON pic.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'closeup_flower'
  )                                             AS closeup_flower_photo_path,
  (SELECT coalesce(jsonb_agg(
     jsonb_build_object('src', pic.file_path, 'contributor', smed.photographer_name)
     ORDER BY smed.sort_order), '[]'::jsonb)
   FROM sighting_media smed JOIN picture pic ON pic.picture_id = smed.picture_id
   WHERE smed.sighting_id = s.sighting_id AND smed.media_category = 'habitat'
  )                                             AS habitat_photo_path,
  -- researcher name: real submitted value first, legacy user-join fallback second
  coalesce(nullif(trim(s.head_observer_name), ''), trim((u.first_name || ' ' || u.last_name)))
                                                 AS researcher_name,
  (SELECT string_agg(stm.member_name, ', ' ORDER BY stm.team_member_id)
   FROM sighting_team_member stm
   WHERE stm.sighting_id = s.sighting_id)       AS team_members,
  -- institution: real submitted value first, legacy affiliation-join fallback second
  coalesce(nullif(trim(s.institution_name), ''), a.affiliation_name)
                                                 AS institution,
  (
    SELECT coalesce(jsonb_agg(c.contributor ORDER BY c.ord), '[]'::jsonb)
    FROM (
      SELECT
        0 AS ord,
        jsonb_build_object(
          'name', coalesce(nullif(trim(s.head_observer_name), ''), trim(both ' ' from coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, ''))),
          'role', 'Head Researcher'
        ) AS contributor
      WHERE coalesce(nullif(trim(s.head_observer_name), ''), trim(both ' ' from coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, ''))) <> ''
      UNION ALL
      SELECT
        stm.team_member_id AS ord,
        jsonb_build_object(
          'name', stm.member_name,
          'role', coalesce(nullif(trim(stm.member_role), ''), 'Team Member')
        ) AS contributor
      FROM sighting_team_member stm
      WHERE stm.sighting_id = s.sighting_id
    ) c
  )                                             AS contributors
FROM species_sightings s
LEFT JOIN mountain              m  ON m.mountain_id              = s.mountain_id
LEFT JOIN municipality          mu ON mu.municipality_id         = m.municipality_id
LEFT JOIN province              p  ON p.province_id              = mu.province_id
LEFT JOIN sighting_habitat      sh ON sh.sighting_habitat_id     = s.sighting_habitat_id
LEFT JOIN sighting_morphology   sm ON sm.sighting_morphology_id  = s.sighting_morphology_id
LEFT JOIN sighting_conservation sc ON sc.sighting_conservation_id = s.sighting_conservation_id
LEFT JOIN "user"                u  ON u.user_id                  = s.user_id
LEFT JOIN affiliation           a  ON a.affiliation_id           = u.affiliation_id
WHERE lower(coalesce(s.review_status, '')) = 'approved'
  AND coalesce(s.catalog_published, true) = true;

GRANT SELECT ON public_approved_sightings TO anon, authenticated;

COMMIT;
