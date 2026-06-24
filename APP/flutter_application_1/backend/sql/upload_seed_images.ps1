# ============================================================
# BLOOM3D - Upload seed orchid images to Supabase Storage
#
# HOW TO RUN:
#   1. Get your Service Role Key from:
#      Supabase Dashboard > Project Settings > API > service_role key
#   2. Open PowerShell and run:
#      .\upload_seed_images.ps1 -ServiceRoleKey "eyJ..."
#
# This uploads 26 storage paths needed by seed_mtbusa.sql:
#   * 10 main species photos  (catalog hero images)
#   * 10 close-up flower photos
#   *  6 habitat photos
#
# Close-up and habitat images reuse the available local files
# as seed placeholders. Real field photos can replace them later.
# ============================================================

param(
  [Parameter(Mandatory=$true)]
  [string]$ServiceRoleKey
)

$supabaseUrl = "https://fmvkxvmrycsubjmkyaet.supabase.co"
$bucket      = "bloom-uploads"
$imgFolder   = Join-Path $PSScriptRoot "..\..\orchid img"

# Map: local filename -> storage path inside bloom-uploads
# Multiple storage paths may share the same local source file (seed placeholders).
$uploads = @(
  # --- Main species photos (catalog hero images) ---
  @{ file="Orchid-Festival.-Phalaenoposis_17A1961-1024x683.jpg";   path="sightings/seed_vanda_sanderiana.jpg"          },
  @{ file="Dendrobium-nobile-768x1024.jpeg";                        path="sightings/seed_dendrobium_secundum.jpg"       },
  @{ file="Laelia-anceps_21A2640-2000x1125.jpg";                    path="sightings/seed_spathoglottis_plicata.jpg"     },
  @{ file="Vanilla-planifolia_19A0347-683x1024.jpg";                path="sightings/seed_aerides_quinquevulnera.jpg"    },
  @{ file="Miltonia orchid.jpg";                                    path="sightings/seed_coelogyne_asperata.jpg"        },
  @{ file="Bulbophyllum-phalaenopsis_19A9045-683x1024.jpg";         path="sightings/seed_bulbophyllum_lobbii.jpg"       },
  @{ file="Dactylorhiza fuchsii.jpg";                               path="sightings/seed_trichoglottis_brachiata.jpg"   },
  @{ file="Orchid-Festival.-Phalaenoposis_17A1958-683x1024.jpg";    path="sightings/seed_calanthe_triplicata.jpg"       },
  @{ file="Paphiopedilum-insigne_24A8674-683x1024.jpg";             path="sightings/seed_paphiopedilum_fowliei.jpg"     },
  @{ file="Phalaenoposis.jpg";                                      path="sightings/seed_phalaenopsis_schilleriana.jpg" },

  # --- Close-up flower photos ---
  @{ file="Orchid-Festival.-Phalaenoposis_17A1961-1024x683.jpg";   path="sightings/seed_closeup_vanda.jpg"            },
  @{ file="Phalaenopsis-mannii20160070_17A6536-683x1024.jpg";       path="sightings/seed_closeup_phalaenopsis.jpg"     },
  @{ file="Dendrobium-nobile-768x1024.jpeg";                        path="sightings/seed_closeup_dendrobium.jpg"       },
  @{ file="Laelia-anceps_21A2640-2000x1125.jpg";                    path="sightings/seed_closeup_spathoglottis.jpg"    },
  @{ file="Vanilla-planifolia_19A0347-683x1024.jpg";                path="sightings/seed_closeup_aerides.jpg"          },
  @{ file="Miltonia orchid.jpg";                                    path="sightings/seed_closeup_coelogyne.jpg"        },
  @{ file="Bulbophyllum-phalaenopsis_19A9045-683x1024.jpg";         path="sightings/seed_closeup_bulbophyllum.jpg"     },
  @{ file="Dactylorhiza fuchsii.jpg";                               path="sightings/seed_closeup_trichoglottis.jpg"    },
  @{ file="Orchid-Festival.-Phalaenoposis_17A1958-683x1024.jpg";    path="sightings/seed_closeup_calanthe.jpg"         },
  @{ file="Paphiopedilum-insigne_24A8674-683x1024.jpg";             path="sightings/seed_closeup_paphiopedilum.jpg"    },

  # --- Habitat photos ---
  @{ file="Bulbophyllum-phalaenopsis_19A9045-683x1024.jpg";         path="sightings/seed_habitat_montane.jpg"          },
  @{ file="Dactylorhiza fuchsii.jpg";                               path="sightings/seed_habitat_stream.jpg"           },
  @{ file="Laelia-anceps_21A2640-2000x1125.jpg";                    path="sightings/seed_habitat_grassland.jpg"        },
  @{ file="Miltonia orchid.jpg";                                    path="sightings/seed_habitat_mossy.jpg"            },
  @{ file="Vanilla-planifolia_19A0347-683x1024.jpg";                path="sightings/seed_habitat_forest_edge.jpg"      },
  @{ file="Orchid-Festival.-Phalaenoposis_17A1958-683x1024.jpg";    path="sightings/seed_habitat_limestone.jpg"        }
)

$ok   = 0
$fail = 0

foreach ($u in $uploads) {
  $localPath = Join-Path $imgFolder $u.file
  if (-not (Test-Path $localPath)) {
    Write-Host "  SKIP (not found): $($u.file)"
    continue
  }

  $bytes   = [System.IO.File]::ReadAllBytes($localPath)
  $ext     = [System.IO.Path]::GetExtension($u.file).ToLower()
  $ct      = if ($ext -eq ".jpeg" -or $ext -eq ".jpg") { "image/jpeg" } else { "image/png" }
  $uri     = "$supabaseUrl/storage/v1/object/$bucket/$($u.path)"
  $headers = @{
    "Authorization" = "Bearer $ServiceRoleKey"
    "Content-Type"  = $ct
    "x-upsert"      = "true"
  }

  try {
    $resp = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $bytes -UseBasicParsing -ErrorAction Stop
    Write-Host "  OK  ($($resp.StatusCode)): $($u.path)"
    $ok++
  } catch {
    $code = $_.Exception.Response.StatusCode.Value__
    $body = $_.ErrorDetails.Message
    Write-Host "  FAIL ($code): $($u.path) - $body"
    $fail++
  }
}

Write-Host ""
Write-Host "Done: $ok uploaded, $fail failed."
Write-Host ""
Write-Host "After all uploads succeed, run seed_mtbusa.sql in the Supabase SQL Editor."
