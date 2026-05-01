BEGIN;

CREATE OR REPLACE VIEW public_approved_sightings AS
SELECT
  s.sighting_id AS id,
  s.scientific_name,
  CASE
    WHEN lower(coalesce(s.identification_confidence, '')) = 'confirmed' THEN 'Verified'
    ELSE 'Unverified'
  END AS verification_status,
  s.observation_type,
  s.observation_date,
  to_char(s.observation_date, 'YYYY-MM') AS observation_month,
  s.mountain_name,
  s.habitat_type,
  s.flower_color,
  s.blooming_stage AS flowering_stage,
  s.population_status,
  s.growth_substrate,
  s.light_exposure,
  s.soil_type,
  s.nearby_water_source,
  'Location hidden for conservation'::text AS location_visibility_note,
  s.whole_plant_photo_path,
  s.closeup_flower_photo_path,
  s.habitat_photo_path
FROM species_sightings s
WHERE lower(coalesce(s.review_status, '')) = 'approved';

GRANT SELECT ON public_approved_sightings TO anon, authenticated;

COMMIT;