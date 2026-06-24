-- Adds latitude and longitude to public_approved_sightings so the
-- catalog map can show all sighting markers.
-- Run this in the Supabase SQL Editor.

BEGIN;

DROP VIEW IF EXISTS public_approved_sightings;

CREATE OR REPLACE VIEW public_approved_sightings AS
SELECT
  s.sighting_id AS id,
  s.scientific_name,
  s.common_names,
  s.identification_confidence,
  s.observation_date,
  to_char(s.observation_date, 'YYYY-MM') AS observation_month,
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
  s.researcher_name,
  s.team_members,
  s.institution,
  CASE
    WHEN lower(coalesce(s.threat_level, '')) IN ('critically endangered', 'endangered', 'vulnerable', 'threatened') THEN 'Threatened'
    WHEN lower(coalesce(s.threat_level, '')) <> '' THEN 'Threatened'
    ELSE ''
  END AS threat_level_generalized,
  s.growth_substrate,
  s.nearby_water_source,
  NULL::text AS educational_notes,
  'Location hidden for conservation'::text AS location_visibility_note,
  s.whole_plant_photo_path,
  s.closeup_flower_photo_path,
  s.habitat_photo_path
FROM species_sightings s
WHERE lower(coalesce(s.review_status, '')) = 'approved';

GRANT SELECT ON public_approved_sightings TO anon, authenticated;

COMMIT;