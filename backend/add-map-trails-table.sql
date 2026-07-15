BEGIN;

-- DENR-managed trail routes shown on the Mt. Busa map (both DENR and
-- researcher dashboards read from this table so a trail added by DENR
-- shows up on both maps).
CREATE TABLE IF NOT EXISTS map_trails (
  trail_id    SERIAL PRIMARY KEY,
  name        VARCHAR(255) NOT NULL,
  description TEXT,
  color       VARCHAR(20) NOT NULL DEFAULT '#2563eb',
  coordinates JSONB NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Carry over the trail that used to be hardcoded in the frontend, now in blue.
INSERT INTO map_trails (name, description, color, coordinates)
SELECT
  'Mt. Busa Research Trail',
  'Primary orchid survey trail. Starts at trailhead (~6.07°N) and ascends to the upper survey zone (~6.11°N). Sourced from BLOOM mobile app.',
  '#2563eb',
  '[[6.0705,124.7412],[6.0758,124.7350],[6.0821,124.7284],[6.0903,124.7201],[6.0987,124.7128],[6.1055,124.7049],[6.1092,124.6858]]'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM map_trails WHERE name = 'Mt. Busa Research Trail');

GRANT SELECT ON map_trails TO anon, authenticated;
GRANT INSERT ON map_trails TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE map_trails_trail_id_seq TO authenticated;

COMMIT;
