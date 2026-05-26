-- Updates public_approved_sightings to expose all fields needed by the
-- orchid detail page: actual threat_level, local_names, lat/lng, observation
-- details (time, type, method, voucher), researcher_notes, and endemic flag.
-- Run in the Supabase SQL Editor.

BEGIN;

DROP VIEW IF EXISTS public_approved_sightings;

CREATE VIEW public_approved_sightings AS
SELECT
  s.sighting_id                     AS id,
  s.scientific_name,
  s.common_names,
  s.local_names,
  s.identification_confidence,
  s.observation_date,
  to_char(s.observation_date, 'YYYY-MM') AS observation_month,
  s.observation_time,
  s.observation_type,
  s.collection_method,
  s.voucher_collected,
  s.mountain_name,
  s.specific_site_zone,
  s.latitude,
  s.longitude,
  s.elevation_meters,
  s.habitat_type,
  s.microhabitat,
  s.plant_height_cm,
  s.leaf_shape,
  s.leaf_count,
  s.leaf_textures,
  s.leaf_arrangement,
  s.flower_color,
  s.flower_count,
  s.flower_diameter_cm,
  s.inflorescence_type,
  s.petal_characteristics,
  s.labellum_lip_description,
  s.fragrance,
  s.flowering_season,
  s.blooming_stage,
  s.fruit_present,
  s.fruit_type,
  s.population_status,
  s.threat_level,
  coalesce(s.threat_level, '')      AS threat_level_generalized,
  s.endemic_to_philippines,
  s.growth_substrate,
  s.nearby_water_source,
  s.researcher_notes,
  NULL::text                        AS educational_notes,
  'Location hidden for conservation'::text AS location_visibility_note,
  s.whole_plant_photo_path,
  s.closeup_flower_photo_path,
  s.habitat_photo_path,
  s.researcher_name,
  s.team_members,
  s.institution
FROM species_sightings s
WHERE lower(coalesce(s.review_status, '')) = 'approved';

GRANT SELECT ON public_approved_sightings TO anon, authenticated;

COMMIT;
