"""
Update researcher-dashboard.html and denr-dashboard.html to navigate to
orchid-detail.html instead of opening their inline modal.
Also update orchid-detail.html back link to handle the 'from' URL param.
"""

def replace_once(content, old, new, label):
    if old in content:
        content = content.replace(old, new, 1)
        print(f'OK   {label}')
    else:
        print(f'MISS {label}')
    return content

# ── 1. orchid-detail.html — dynamic back link ────────────────────────────────

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'r', encoding='utf-8') as f:
    od = f.read()

od = replace_once(
    od,
    '<a href="catalog.html" class="detail-back-link">&larr; Catalog</a>',
    '<a id="detail-back-link" href="catalog.html" class="detail-back-link">&larr; Catalog</a>',
    'orchid-detail: add id to back link'
)

od = replace_once(
    od,
    "      async function loadPage() {\n        const params = new URLSearchParams(location.search);\n        const nameFromUrl = params.get('name') || '';",
    """      async function loadPage() {
        const params = new URLSearchParams(location.search);
        const nameFromUrl = params.get('name') || '';

        // Update back link based on referrer page
        const fromPage = params.get('from') || '';
        const backLink = document.getElementById('detail-back-link');
        if (backLink) {
          if (fromPage === 'researcher-dashboard') {
            backLink.href = 'researcher-dashboard.html';
            backLink.innerHTML = '&larr; Dashboard';
          } else if (fromPage === 'denr-dashboard') {
            backLink.href = 'denr-dashboard.html';
            backLink.innerHTML = '&larr; Dashboard';
          }
        }""",
    'orchid-detail: dynamic back link JS'
)

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'w', encoding='utf-8') as f:
    f.write(od)
print('orchid-detail.html saved\n')

# ── Shared old function body (identical in both dashboards) ──────────────────

OLD_FN = '''      async function openDashboardOrchidDetails(orchid) {
        const orchidName = hasDashboardUsableValue(orchid.name) ? String(orchid.name).trim() : 'Orchid';

        const mapNameEl = document.getElementById('dashboard-orchid-map-name');
        const stageNameEl = document.getElementById('dashboard-orchid-detail-stage-name');
        if (mapNameEl) mapNameEl.textContent = orchidName;
        if (stageNameEl) stageNameEl.textContent = orchidName;

        const dashboardAddInstanceBtn = document.getElementById('dashboard-add-instance-button');
        if (dashboardAddInstanceBtn) {
          dashboardAddInstanceBtn.hidden = false;
          dashboardAddInstanceBtn.onclick = function() {
            closeDashboardOrchidDetails();
            openResearcherSubmissionModal(orchidName);
          };
        }

        const galleryHandler = function() { openOrchidGallery(orchidName, orchid.image_url || ''); };
        const galleryBtnMap = document.getElementById('dashboard-gallery-btn-map');
        const galleryBtnDetail = document.getElementById('dashboard-gallery-btn-detail');
        if (galleryBtnMap) galleryBtnMap.onclick = galleryHandler;
        if (galleryBtnDetail) galleryBtnDetail.onclick = galleryHandler;

        // Reset all detail rows
        document.querySelectorAll('#dashboard-orchid-detail-stage .orchid-detail-row').forEach(function(row) {
          row.hidden = true;
          const valueEl = row.querySelector('[id^="dashboard-detail-"]');
          if (valueEl) valueEl.textContent = '';
        });

        // Pre-populate basic fields
        setDashboardDetailRow('dashboard-row-scientific-name', 'dashboard-detail-scientific-name', orchid.name);
        setDashboardDetailRow('dashboard-row-genus', 'dashboard-detail-genus', orchid.genus);
        setDashboardDetailRow('dashboard-row-common-name', 'dashboard-detail-common-name', orchid.common_name);
        setDashboardDetailRow('dashboard-row-endemicity', 'dashboard-detail-endemicity', orchid.endemicity);
        setDashboardDetailRow('dashboard-row-ethnobotanical', 'dashboard-detail-ethnobotanical', orchid.ethnobotanical);
        setDashboardDetailRow('dashboard-row-horticulture', 'dashboard-detail-horticulture', orchid.horticulture_value);
        setDashboardDetailRow('dashboard-row-cultural', 'dashboard-detail-cultural', orchid.cultural_importance);

        // Show modal → map stage first
        dashboardOrchidDetailModal.hidden = false;
        document.getElementById('dashboard-orchid-map-stage').hidden = false;
        document.getElementById('dashboard-orchid-detail-stage').hidden = true;
        dashboardOrchidBindDetailNav();

        // Fetch sighting data from Supabase
        let sightingPoints = [];
        if (orchid.name) {
          try {
            const client = window.bloomSupabase || window.supabase;
            if (client && typeof client.from === 'function') {
              const { data, error } = await client
                .from('species_sightings')
                .select('*')
                .ilike('scientific_name', orchid.name.trim())
                .eq('review_status', 'approved')
                .order('observation_date', { ascending: false })
                .limit(10);
              if (!error && data && data.length > 0) {
                const src = data[0];
                sightingPoints = data
                  .filter(s => s.latitude != null && s.longitude != null)
                  .map(s => ({ lat: Number(s.latitude), lng: Number(s.longitude) }));

                setDashboardDetailRow('dashboard-row-common-name', 'dashboard-detail-common-name',
                  (Array.isArray(src.common_names) ? src.common_names[0] : src.common_names) || src.common_name || orchid.common_name);
                setDashboardDetailRow('dashboard-row-identification-status', 'dashboard-detail-identification-status', src.identification_confidence || '');
                setDashboardDetailRow('dashboard-row-identification-confidence', 'dashboard-detail-identification-confidence', src.identification_confidence || '');
                setDashboardDetailRow('dashboard-row-observation-summary', 'dashboard-detail-observation-summary', src.researcher_notes || '');
                setDashboardDetailRow('dashboard-row-observation-type', 'dashboard-detail-observation-type', src.observation_type || '');
                setDashboardDetailRow('dashboard-row-observation-date', 'dashboard-detail-observation-date', src.observation_date || '');
                setDashboardDetailRow('dashboard-row-observation-time', 'dashboard-detail-observation-time', src.observation_time || '');
                setDashboardDetailRow('dashboard-row-collection-method', 'dashboard-detail-collection-method', src.collection_method || '');
                setDashboardDetailRow('dashboard-row-voucher', 'dashboard-detail-voucher', src.voucher_collected === true ? 'Yes' : (src.voucher_collected === false ? 'No' : ''));
                setDashboardDetailRow('dashboard-row-mountain', 'dashboard-detail-mountain', src.mountain_name || '');
                setDashboardDetailRow('dashboard-row-specific-site', 'dashboard-detail-specific-site', src.specific_site_zone || '');
                setDashboardDetailRow('dashboard-row-latitude', 'dashboard-detail-latitude', src.latitude ?? '');
                setDashboardDetailRow('dashboard-row-longitude', 'dashboard-detail-longitude', src.longitude ?? '');
                setDashboardDetailRow('dashboard-row-elevation', 'dashboard-detail-elevation', src.elevation_meters ?? '');
                setDashboardDetailRow('dashboard-row-habitat-type', 'dashboard-detail-habitat-type', src.habitat_type || '');
                setDashboardDetailRow('dashboard-row-microhabitat', 'dashboard-detail-microhabitat', src.microhabitat || '');
                setDashboardDetailRow('dashboard-row-growth-substrate', 'dashboard-detail-growth-substrate', src.growth_substrate || '');
                setDashboardDetailRow('dashboard-row-host-tree', 'dashboard-detail-host-tree', src.host_tree_species || '');
                setDashboardDetailRow('dashboard-row-canopy-cover', 'dashboard-detail-canopy-cover', src.canopy_cover_percent ?? '');
                setDashboardDetailRow('dashboard-row-light-exposure', 'dashboard-detail-light-exposure', src.light_exposure || '');
                setDashboardDetailRow('dashboard-row-soil-type', 'dashboard-detail-soil-type', src.soil_type || '');
                setDashboardDetailRow('dashboard-row-nearby-water', 'dashboard-detail-nearby-water', src.nearby_water_source || '');
                setDashboardDetailRow('dashboard-row-flower-color', 'dashboard-detail-flower-color', src.flower_color || '');
                setDashboardDetailRow('dashboard-row-flowering-stage', 'dashboard-detail-flowering-stage', src.blooming_stage || '');
                setDashboardDetailRow('dashboard-row-plant-height', 'dashboard-detail-plant-height', src.plant_height_cm ?? '');
                setDashboardDetailRow('dashboard-row-pseudobulb', 'dashboard-detail-pseudobulb', src.pseudobulb_present === true ? 'Yes' : (src.pseudobulb_present === false ? 'No' : ''));
                setDashboardDetailRow('dashboard-row-stem-length', 'dashboard-detail-stem-length', src.stem_length_cm ?? '');
                setDashboardDetailRow('dashboard-row-root-length', 'dashboard-detail-root-length', src.root_length_cm ?? '');
                setDashboardDetailRow('dashboard-row-leaf-count', 'dashboard-detail-leaf-count', src.leaf_count ?? '');
                setDashboardDetailRow('dashboard-row-leaf-shape', 'dashboard-detail-leaf-shape', src.leaf_shape || '');
                setDashboardDetailRow('dashboard-row-leaf-textures', 'dashboard-detail-leaf-textures', Array.isArray(src.leaf_textures) ? src.leaf_textures.join(', ') : src.leaf_textures || '');
                setDashboardDetailRow('dashboard-row-leaf-arrangement', 'dashboard-detail-leaf-arrangement', src.leaf_arrangement || '');
                setDashboardDetailRow('dashboard-row-flower-count', 'dashboard-detail-flower-count', src.flower_count ?? '');
                setDashboardDetailRow('dashboard-row-flower-diameter', 'dashboard-detail-flower-diameter', src.flower_diameter_cm ?? '');
                setDashboardDetailRow('dashboard-row-inflorescence-type', 'dashboard-detail-inflorescence-type', src.inflorescence_type || '');
                setDashboardDetailRow('dashboard-row-petal-characteristics', 'dashboard-detail-petal-characteristics', src.petal_characteristics || '');
                setDashboardDetailRow('dashboard-row-sepal-characteristics', 'dashboard-detail-sepal-characteristics', src.sepal_characteristics || '');
                setDashboardDetailRow('dashboard-row-labellum', 'dashboard-detail-labellum', src.labellum_lip_description || '');
                setDashboardDetailRow('dashboard-row-fragrance', 'dashboard-detail-fragrance', src.fragrance || '');
                setDashboardDetailRow('dashboard-row-flowering-season', 'dashboard-detail-flowering-season', src.flowering_season || '');
                setDashboardDetailRow('dashboard-row-fruit-present', 'dashboard-detail-fruit-present', src.fruit_present === true ? 'Yes' : (src.fruit_present === false ? 'No' : ''));
                setDashboardDetailRow('dashboard-row-fruit-type', 'dashboard-detail-fruit-type', src.fruit_type || '');
                setDashboardDetailRow('dashboard-row-seed-capsule', 'dashboard-detail-seed-capsule', src.seed_capsule_condition || '');
                setDashboardDetailRow('dashboard-row-life-stage', 'dashboard-detail-life-stage', src.life_stage || '');
                setDashboardDetailRow('dashboard-row-phenology', 'dashboard-detail-phenology', src.phenology || '');
                setDashboardDetailRow('dashboard-row-population-count', 'dashboard-detail-population-count', src.population_count ?? '');
                setDashboardDetailRow('dashboard-row-population-status', 'dashboard-detail-population-status', src.population_status || '');
                setDashboardDetailRow('dashboard-row-threat-level', 'dashboard-detail-threat-level', src.threat_level || '');
                setDashboardDetailRow('dashboard-row-threat-types', 'dashboard-detail-threat-types', Array.isArray(src.threat_types) ? src.threat_types.join(', ') : src.threat_types || '');
                setDashboardDetailRow('dashboard-row-institution', 'dashboard-detail-institution', src.institution || '');
                setDashboardDetailRow('dashboard-row-researcher', 'dashboard-detail-researcher', src.researcher_name || '');
                setDashboardDetailRow('dashboard-row-team-members', 'dashboard-detail-team-members', src.team_members || '');
              }
            }
          } catch (e) {
            console.warn('Failed to load sighting for dashboard orchid detail:', e);
          }
        }

        if (sightingPoints.length === 0) sightingPoints.push({ lat: 6.109410, lng: 124.663094 });
        setTimeout(() => dashboardOrchidInitMap(sightingPoints), 60);
      }'''

# ── 2. researcher-dashboard.html ─────────────────────────────────────────────

NEW_RESEARCHER_FN = '''      async function openDashboardOrchidDetails(orchid) {
        let sightings = [];
        if (orchid.name) {
          try {
            const client = window.bloomSupabase || window.supabase;
            if (client && typeof client.from === 'function') {
              const { data, error } = await client
                .from('species_sightings')
                .select('*')
                .ilike('scientific_name', orchid.name.trim())
                .eq('review_status', 'approved')
                .order('observation_date', { ascending: false })
                .limit(10);
              if (!error && data) sightings = data;
            }
          } catch (e) {
            console.warn('Failed to load sightings for orchid detail:', e);
          }
        }
        try {
          sessionStorage.setItem('bloomOrchidDetail', JSON.stringify({ orchid, sightings }));
        } catch {}
        window.location.href = 'orchid-detail.html?name=' + encodeURIComponent(orchid.name || '') + '&from=researcher-dashboard';
      }'''

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\researcher-dashboard.html', 'r', encoding='utf-8') as f:
    rd = f.read()

rd = replace_once(rd, OLD_FN, NEW_RESEARCHER_FN, 'researcher-dashboard: openDashboardOrchidDetails')

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\researcher-dashboard.html', 'w', encoding='utf-8') as f:
    f.write(rd)
print('researcher-dashboard.html saved\n')

# ── 3. denr-dashboard.html ────────────────────────────────────────────────────

NEW_DENR_FN = '''      async function openDashboardOrchidDetails(orchid) {
        let sightings = [];
        if (orchid.name) {
          try {
            const client = window.bloomSupabase || window.supabase;
            if (client && typeof client.from === 'function') {
              const { data, error } = await client
                .from('species_sightings')
                .select('*')
                .ilike('scientific_name', orchid.name.trim())
                .eq('review_status', 'approved')
                .order('observation_date', { ascending: false })
                .limit(10);
              if (!error && data) sightings = data;
            }
          } catch (e) {
            console.warn('Failed to load sightings for orchid detail:', e);
          }
        }
        try {
          sessionStorage.setItem('bloomOrchidDetail', JSON.stringify({ orchid, sightings }));
        } catch {}
        window.location.href = 'orchid-detail.html?name=' + encodeURIComponent(orchid.name || '') + '&from=denr-dashboard';
      }'''

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\denr-dashboard.html', 'r', encoding='utf-8') as f:
    dd = f.read()

dd = replace_once(dd, OLD_FN, NEW_DENR_FN, 'denr-dashboard: openDashboardOrchidDetails')

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\denr-dashboard.html', 'w', encoding='utf-8') as f:
    f.write(dd)
print('denr-dashboard.html saved\n')

print('All done.')