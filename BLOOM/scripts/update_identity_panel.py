import re

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'r', encoding='utf-8') as f:
    content = f.read()

# ── 1. Replace identity panel HTML ──────────────────────────────────────────
old_info = '''        <div class="oid-info">
          <h3 id="oid-sci-name" class="oid-sci-name">-</h3>
          <p id="oid-common-name" class="oid-common-name"></p>
          <div class="oid-meta-table">
            <div class="oid-meta-row">
              <span class="oid-meta-label">Family</span>
              <span class="oid-meta-value" id="oid-family">Orchidaceae</span>
            </div>
            <div class="oid-meta-row" id="oid-row-genus">
              <span class="oid-meta-label">Genus</span>
              <span class="oid-meta-value" id="oid-genus">-</span>
            </div>
            <div class="oid-meta-row">
              <span class="oid-meta-label">Location</span>
              <span class="oid-meta-value" id="oid-mountain">Mt. Busa</span>
            </div>
          </div>
          <div class="oid-badges">
            <span class="oid-badge oid-badge-status" id="oid-status-badge" hidden>-</span>
            <span class="oid-badge oid-badge-confidence" id="oid-confidence-badge" hidden>-</span>
          </div>
        </div>'''

new_info = '''        <div class="oid-info">
          <h3 id="oid-sci-name" class="oid-sci-name">-</h3>
          <p id="oid-common-name" class="oid-common-name"></p>
          <div class="oid-field-list">
            <div class="oid-field-row"><span class="oid-field-label">Family</span><span class="oid-field-value" id="oid-family">Orchidaceae</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Genus</span><span class="oid-field-value" id="oid-genus">&mdash;</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Local Names</span><span class="oid-field-value" id="oid-local-names">&mdash;</span></div>
            <div class="oid-field-row oid-field-sep"><span class="oid-field-label">Conservation Status</span><span class="oid-field-value" id="oid-conservation-status">&mdash;</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Typical Habitat</span><span class="oid-field-value" id="oid-habitat">&mdash;</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Growth Substrate</span><span class="oid-field-value" id="oid-substrate">&mdash;</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Flower Color</span><span class="oid-field-value" id="oid-flower-color">&mdash;</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Flowering Season</span><span class="oid-field-value" id="oid-flowering-season">&mdash;</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Distribution</span><span class="oid-field-value" id="oid-distribution">Philippines</span></div>
            <div class="oid-field-row"><span class="oid-field-label">Endemic</span><span class="oid-field-value" id="oid-endemic">&mdash;</span></div>
          </div>
        </div>'''

assert old_info in content, 'OLD INFO NOT FOUND'
content = content.replace(old_info, new_info, 1)
print('Identity panel HTML replaced')

# ── 2. Fix photo CSS + add field list CSS ────────────────────────────────────
old_photo_css = '      .oid-photo-wrap { width: 100%; aspect-ratio: 16/10; overflow: hidden; background: #eaf4e7; flex-shrink: 0; }\n      .oid-photo { width: 100%; height: 100%; object-fit: cover; display: block; transition: transform .4s; }\n      .oid-photo:hover { transform: scale(1.04); }\n      .oid-photo-placeholder { width: 100%; height: 100%; object-fit: contain; padding: 2rem; opacity: .28; }'

new_photo_css = '      .oid-photo-wrap { width: 100%; aspect-ratio: 4/3; overflow: hidden; background: #fff; flex-shrink: 0; display: flex; align-items: center; justify-content: center; }\n      .oid-photo { width: 100%; height: 100%; object-fit: contain; display: block; padding: 6px; }\n      .oid-photo-placeholder { width: 100%; height: 100%; object-fit: contain; padding: 2.5rem; opacity: .55; }'

if old_photo_css in content:
    content = content.replace(old_photo_css, new_photo_css, 1)
    print('Photo CSS replaced')
else:
    print('Photo CSS not found, trying regex')
    content = re.sub(
        r'\.oid-photo-wrap \{[^}]+\}\s*\.oid-photo \{[^}]+\}\s*\.oid-photo:hover \{[^}]+\}\s*\.oid-photo-placeholder \{[^}]+\}',
        new_photo_css.strip(),
        content,
        count=1,
        flags=re.DOTALL
    )
    print('Photo CSS replaced via regex')

# Add field list CSS (insert after .oid-common-name rule)
field_css = '''
      .oid-field-list { display: flex; flex-direction: column; }
      .oid-field-row { display: flex; justify-content: space-between; align-items: flex-start; padding: .46rem 0; border-bottom: 1px solid #f0f5ef; gap: .5rem; }
      .oid-field-row:last-child { border-bottom: none; }
      .oid-field-sep { border-top: 2px solid #e0eedd; margin-top: .35rem; padding-top: .55rem; }
      .oid-field-label { font-size: .68rem; font-weight: 700; color: #5a8a54; text-transform: uppercase; letter-spacing: .08em; flex-shrink: 0; min-width: 42%; line-height: 1.4; padding-top: .05rem; }
      .oid-field-value { font-size: .84rem; font-weight: 500; color: #1c3d18; text-align: right; max-width: 58%; line-height: 1.4; }'''

# Insert after the .oid-common-name rule
insert_after = '.oid-common-name { font-size: .88rem; color: #4a7a44; margin: 0 0 1.1rem; font-weight: 500; min-height: 1.2em; }'
if insert_after in content:
    content = content.replace(insert_after, insert_after + field_css, 1)
    print('Field list CSS added')
else:
    print('WARNING: Could not find .oid-common-name to insert after')

# ── 3. Replace populateIdentityPanel JS ─────────────────────────────────────
old_js = '''      function populateIdentityPanel(orchid, src) {
        const orchidName = hasUsableValue(orchid.name) ? String(orchid.name).trim() : 'Orchid';

        document.getElementById('detail-topbar-name').textContent = orchidName;
        document.getElementById('orchid-detail-stage-name').textContent = orchidName;
        document.getElementById('oid-sci-name').textContent = orchidName;

        const commonName = getPrimaryCommonName(src.common_names) || orchid.common_name || '';
        const commonNameEl = document.getElementById('oid-common-name');
        if (commonNameEl) commonNameEl.textContent = commonName;

        const genus = orchid.genus || orchidName.split(' ')[0] || '';
        const genusEl = document.getElementById('oid-genus');
        if (genusEl) genusEl.textContent = genus;
        const genusRowEl = document.getElementById('oid-row-genus');
        if (genusRowEl) genusRowEl.hidden = !genus;

        const mountainEl = document.getElementById('oid-mountain');
        if (mountainEl) mountainEl.textContent = src.mountain_name || 'Mt. Busa';

        // Photo
        const oidPhoto = document.getElementById('oid-photo');
        const oidPhotoPlaceholder = document.getElementById('oid-photo-placeholder');
        const images = getPublicSightingImages(src);
        if (images.length > 0 && oidPhoto) {
          oidPhoto.src = images[0];
          oidPhoto.hidden = false;
          if (oidPhotoPlaceholder) oidPhotoPlaceholder.hidden = true;
        } else if (orchid.image_url && oidPhoto) {
          oidPhoto.src = orchid.image_url;
          oidPhoto.hidden = false;
          if (oidPhotoPlaceholder) oidPhotoPlaceholder.hidden = true;
        } else if (oidPhoto && oidPhotoPlaceholder) {
          oidPhoto.hidden = true;
          oidPhotoPlaceholder.hidden = false;
        }

        // Status badge
        const oidStatusBadge = document.getElementById('oid-status-badge');
        const threatLevel = src.threat_level_generalized || '';
        if (oidStatusBadge) {
          if (threatLevel) {
            const tl = threatLevel.toLowerCase();
            oidStatusBadge.textContent = threatLevel;
            oidStatusBadge.className = 'oid-badge oid-badge-status';
            if (tl.includes('critical')) oidStatusBadge.classList.add('critical');
            else if (tl.includes('endanger')) oidStatusBadge.classList.add('endangered');
            else if (tl.includes('vulnerable')) oidStatusBadge.classList.add('vulnerable');
            else oidStatusBadge.classList.add('least-concern');
            oidStatusBadge.hidden = false;
          } else {
            oidStatusBadge.hidden = true;
          }
        }

        // Confidence badge
        const oidConfidenceBadge = document.getElementById('oid-confidence-badge');
        const confidence = src.identification_confidence || '';
        if (oidConfidenceBadge) {
          oidConfidenceBadge.textContent = confidence;
          oidConfidenceBadge.hidden = !confidence;
        }
      }'''

new_js = '''      function setField(id, value) {
        const el = document.getElementById(id);
        if (el) el.textContent = hasUsableValue(value) ? String(value).trim() : '—';
      }

      function populateIdentityPanel(orchid, src) {
        const orchidName = hasUsableValue(orchid.name) ? String(orchid.name).trim() : 'Orchid';

        document.getElementById('detail-topbar-name').textContent = orchidName;
        document.getElementById('orchid-detail-stage-name').textContent = orchidName;
        document.getElementById('oid-sci-name').textContent = orchidName;

        const commonName = getPrimaryCommonName(src.common_names) || orchid.common_name || '';
        const commonNameEl = document.getElementById('oid-common-name');
        if (commonNameEl) commonNameEl.textContent = commonName;

        // Taxonomy
        const genus = orchid.genus || orchidName.split(' ')[0] || '';
        setField('oid-genus', genus);
        setField('oid-family', 'Orchidaceae');

        // Local names (all common names joined)
        const allCommonNames = Array.isArray(src.common_names) ? src.common_names.filter(Boolean) : [];
        setField('oid-local-names', allCommonNames.length > 0 ? allCommonNames.join(', ') : null);

        // Conservation status
        setField('oid-conservation-status', src.threat_level_generalized || null);

        // Habitat & morphology
        setField('oid-habitat', src.habitat_type || null);
        setField('oid-substrate', src.growth_substrate || null);
        setField('oid-flower-color', src.flower_color || null);
        setField('oid-flowering-season', src.flowering_season || null);

        // Distribution & endemicity
        const endemicity = orchid.endemicity || '';
        const distrib = endemicity && !endemicity.toLowerCase().includes('endemic')
          ? endemicity
          : (src.mountain_name ? 'Mindanao, Philippines' : 'Philippines');
        setField('oid-distribution', distrib);
        if (endemicity) {
          const isEndemic = endemicity.toLowerCase().includes('endemic');
          setField('oid-endemic', isEndemic ? 'Yes' : endemicity);
        } else {
          setField('oid-endemic', null);
        }

        // Photo
        const oidPhoto = document.getElementById('oid-photo');
        const oidPhotoPlaceholder = document.getElementById('oid-photo-placeholder');
        const images = getPublicSightingImages(src);
        if (images.length > 0 && oidPhoto) {
          oidPhoto.src = images[0];
          oidPhoto.hidden = false;
          if (oidPhotoPlaceholder) oidPhotoPlaceholder.hidden = true;
        } else if (orchid.image_url && oidPhoto) {
          oidPhoto.src = orchid.image_url;
          oidPhoto.hidden = false;
          if (oidPhotoPlaceholder) oidPhotoPlaceholder.hidden = true;
        } else if (oidPhoto && oidPhotoPlaceholder) {
          oidPhoto.hidden = true;
          oidPhotoPlaceholder.hidden = false;
        }
      }'''

assert old_js in content, 'OLD JS NOT FOUND'
content = content.replace(old_js, new_js, 1)
print('JS populateIdentityPanel replaced')

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'w', encoding='utf-8') as f:
    f.write(content)
print('All done - orchid-detail.html updated')