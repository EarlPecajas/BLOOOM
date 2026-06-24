BEGIN;

INSERT INTO orchids (genus_id, sci_name, common_name, endemicity, date_discovered)
SELECT g.genus_id, 'Dendrobium sample', 'Sample Orchid', 'Not evaluated', NOW()
FROM genus g
WHERE g.genus_name = 'Dendrobium'
ON CONFLICT (sci_name) DO NOTHING;

COMMIT;
