require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY,
  { auth: { persistSession: false } }
);

// 4 extra offsets per species — spread realistically across Mt. Busa ridges
const OFFSETS = [
  { dlat:  0.0083, dlng:  0.0121, site: 'North Ridge Trail',   elevation_add:  40 },
  { dlat: -0.0147, dlng:  0.0063, site: 'East Slope Zone',     elevation_add: -30 },
  { dlat:  0.0201, dlng: -0.0097, site: 'Upper Forest Belt',   elevation_add:  90 },
  { dlat: -0.0069, dlng: -0.0182, site: 'West Ravine Area',    elevation_add: -55 },
];

async function run() {
  // Fetch all existing approved sightings (one per species)
  const { data: existing, error: fetchErr } = await supabase
    .from('species_sightings')
    .select('scientific_name, common_names, identification_confidence, observation_date, mountain_name, latitude, longitude, elevation_meters, habitat_type, microhabitat, growth_substrate, flower_color, blooming_stage, population_status, threat_level, researcher_name, institution')
    .eq('review_status', 'approved');

  if (fetchErr) {
    console.error('Failed to fetch sightings:', fetchErr.message);
    process.exit(1);
  }

  if (!existing || existing.length === 0) {
    console.log('No approved sightings found. Nothing to seed.');
    return;
  }

  // Deduplicate by scientific_name — keep one base per species
  const bySpecies = new Map();
  for (const row of existing) {
    const key = row.scientific_name.trim().toLowerCase();
    if (!bySpecies.has(key)) bySpecies.set(key, row);
  }

  console.log(`Found ${bySpecies.size} approved species. Adding up to 4 extra sightings each...\n`);

  let inserted = 0;
  let skipped = 0;

  for (const [, base] of bySpecies) {
    for (let i = 0; i < OFFSETS.length; i++) {
      const off = OFFSETS[i];
      const entryId = `extra-${base.scientific_name.replace(/\s+/g, '-').toLowerCase()}-${i + 1}`;

      // Check if already inserted
      const { data: exists } = await supabase
        .from('species_sightings')
        .select('sighting_id')
        .eq('entry_id', entryId)
        .maybeSingle();

      if (exists) {
        skipped++;
        continue;
      }

      const lat = Number(base.latitude) + off.dlat;
      const lng = Number(base.longitude) + off.dlng;
      const elev = base.elevation_meters
        ? Number(base.elevation_meters) + off.elevation_add
        : 1200 + off.elevation_add;

      const { error: insertErr } = await supabase
        .from('species_sightings')
        .insert({
          entry_id: entryId,
          researcher_name: base.researcher_name || 'BLOOM Research Team',
          institution: base.institution || 'MSU-Gensan',
          scientific_name: base.scientific_name,
          common_names: base.common_names || [],
          identification_confidence: base.identification_confidence || 'Confirmed',
          observation_date: base.observation_date || '2025-03-15',
          mountain_name: base.mountain_name || 'Mt. Busa',
          specific_site_zone: off.site,
          latitude: lat,
          longitude: lng,
          elevation_meters: elev,
          habitat_type: base.habitat_type || 'Montane Forest',
          microhabitat: base.microhabitat || null,
          growth_substrate: base.growth_substrate || null,
          flower_color: base.flower_color || null,
          blooming_stage: base.blooming_stage || null,
          population_status: base.population_status || null,
          threat_level: base.threat_level || null,
          leaf_textures: [],
          threat_types: [],
          review_status: 'approved',
        });

      if (insertErr) {
        console.error(`  ✗ ${base.scientific_name} sighting ${i + 1}: ${insertErr.message}`);
      } else {
        console.log(`  ✓ ${base.scientific_name} — sighting ${i + 1} at (${lat.toFixed(4)}, ${lng.toFixed(4)}) [${off.site}]`);
        inserted++;
      }
    }
  }

  console.log(`\nDone. Inserted: ${inserted}, Already existed (skipped): ${skipped}`);
}

run().catch(e => { console.error(e); process.exit(1); });