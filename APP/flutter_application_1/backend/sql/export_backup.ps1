# ============================================================
# BLOOM3D — Export orchid data as a backup before reseeding
#
# HOW TO RUN:
#   .\export_backup.ps1 -ServiceRoleKey "eyJ..."
#
# OUTPUT: backend/sql/backup_<timestamp>/
#   *.json          — raw table data
#   restore.sql     — run in Supabase SQL Editor to undo seed
# ============================================================

param(
  [Parameter(Mandatory=$true)]
  [string]$ServiceRoleKey
)

$base    = "https://fmvkxvmrycsubjmkyaet.supabase.co"
$outDir  = Join-Path $PSScriptRoot ("backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $outDir | Out-Null
Write-Host "Saving to: $outDir"

$hdrs = @{
  "Authorization" = "Bearer $ServiceRoleKey"
  "apikey"        = $ServiceRoleKey
  "Accept"        = "application/json"
  "Prefer"        = "count=none"
}

$tables = @(
  "genus", "orchids", "province", "municipality", "mountain",
  "orchid_location", "habitat_information", "species_value",
  "morphological_characteristics", "conservation_status",
  "picture", "model_3d", "species_sightings"
)

$data = @{}
foreach ($t in $tables) {
  try {
    $r = Invoke-WebRequest -Uri "$base/rest/v1/$t`?select=*&limit=10000" -Headers $hdrs -UseBasicParsing -ErrorAction Stop
    $rows = $r.Content | ConvertFrom-Json
    $cnt  = if ($rows -is [array]) { $rows.Count } else { 1 }
    $r.Content | Out-File -FilePath (Join-Path $outDir "$t.json") -Encoding utf8
    $data[$t] = $rows
    Write-Host ("  OK   {0,-35} {1} rows" -f $t, $cnt)
  } catch {
    Write-Host ("  SKIP {0,-35} {1}" -f $t, $_.Exception.Message)
    $data[$t] = @()
  }
}

# ── helpers ───────────────────────────────────────────────────────────────
function sq($v) { if ($null -eq $v -or "$v" -eq "") { return "NULL" }; return ("'" + ("$v" -replace "'","''") + "'") }
function nb($v) { if ($null -eq $v) { return "NULL" }; if ($v) { return "TRUE" } else { return "FALSE" } }
function nd($v) { if ($null -eq $v -or "$v" -eq "") { return "NULL" }; return "$v" }
function jb($v) { if ($null -eq $v) { return "'[]'::jsonb" }; return ("'" + ("$v" -replace "'","''") + "'::jsonb") }

# ── build restore.sql ─────────────────────────────────────────────────────
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("-- BLOOM3D restore.sql  generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("-- Run in Supabase SQL Editor to restore data before the seed.")
$lines.Add("")
$lines.Add("DELETE FROM species_sightings;")
$lines.Add("DELETE FROM orchids;")
$lines.Add("DELETE FROM genus;")
$lines.Add("")

# genus
$gRows = $data["genus"]
if ($gRows -and $gRows.Count -gt 0) {
  $lines.Add("-- genus")
  foreach ($r in $gRows) {
    $lines.Add("INSERT INTO genus (genus_id, genus_name) VALUES ($($r.genus_id), $(sq $r.genus_name)) ON CONFLICT (genus_id) DO NOTHING;")
  }
  $lines.Add("SELECT setval('genus_genus_id_seq', (SELECT MAX(genus_id) FROM genus));")
  $lines.Add("")
}

# orchids
$oRows = $data["orchids"]
if ($oRows -and $oRows.Count -gt 0) {
  $lines.Add("-- orchids  ($($oRows.Count) rows)")
  foreach ($r in $oRows) {
    $lines.Add("INSERT INTO orchids (orchid_id, sci_name, common_name, genus_id) VALUES ($($r.orchid_id), $(sq $r.sci_name), $(sq $r.common_name), $(nd $r.genus_id)) ON CONFLICT (orchid_id) DO NOTHING;")
  }
  $lines.Add("SELECT setval('orchids_orchid_id_seq', (SELECT MAX(orchid_id) FROM orchids));")
  $lines.Add("")
}

# species_sightings
$sRows = $data["species_sightings"]
if ($sRows -and $sRows.Count -gt 0) {
  $lines.Add("-- species_sightings  ($($sRows.Count) rows)")
  foreach ($r in $sRows) {
    $cols = "sighting_id, entry_id, researcher_email, researcher_name, scientific_name, observation_date, observation_time, collection_method, observation_type, voucher_collected, mountain_name, specific_site_zone, latitude, longitude, elevation_meters, habitat_type, microhabitat, leaf_shape, flower_color, life_stage, phenology, population_count, population_status, threat_level, threat_types, institution, team_members, researcher_notes, whole_plant_photo_path, closeup_flower_photo_path, habitat_photo_path, study_title, study_link, review_status, created_at"
    $vals = "$($r.sighting_id), $(sq $r.entry_id), $(sq $r.researcher_email), $(sq $r.researcher_name), $(sq $r.scientific_name), $(sq $r.observation_date), $(sq $r.observation_time), $(sq $r.collection_method), $(sq $r.observation_type), $(nb $r.voucher_collected), $(sq $r.mountain_name), $(sq $r.specific_site_zone), $(nd $r.latitude), $(nd $r.longitude), $(nd $r.elevation_meters), $(sq $r.habitat_type), $(sq $r.microhabitat), $(sq $r.leaf_shape), $(sq $r.flower_color), $(sq $r.life_stage), $(sq $r.phenology), $(nd $r.population_count), $(sq $r.population_status), $(sq $r.threat_level), $(jb $r.threat_types), $(sq $r.institution), $(sq $r.team_members), $(sq $r.researcher_notes), $(sq $r.whole_plant_photo_path), $(sq $r.closeup_flower_photo_path), $(sq $r.habitat_photo_path), $(sq $r.study_title), $(sq $r.study_link), $(sq $r.review_status), $(sq $r.created_at)"
    $lines.Add("INSERT INTO species_sightings ($cols) VALUES ($vals) ON CONFLICT (sighting_id) DO NOTHING;")
  }
  $lines.Add("SELECT setval('species_sightings_sighting_id_seq', (SELECT MAX(sighting_id) FROM species_sightings));")
  $lines.Add("")
}

$lines | Out-File -FilePath (Join-Path $outDir "restore.sql") -Encoding utf8

Write-Host ""
Write-Host "Backup complete!"
Write-Host "  Folder : $outDir"
Write-Host "  Restore: paste restore.sql into Supabase SQL Editor to undo the seed"
