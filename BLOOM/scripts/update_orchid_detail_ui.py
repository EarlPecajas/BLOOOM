"""
Comprehensive orchid-detail.html update:
1. Back link always goes to catalog.html
2. Orchid name moved from topbar to map panel (centered)
3. UI polish matching BLOOM theme
"""

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'r', encoding='utf-8') as f:
    content = f.read()

def rep(old, new, label):
    if old in content:
        print(f'OK   {label}')
        return content.replace(old, new, 1)
    print(f'MISS {label}')
    return content

# ── 1. CSS overhaul ───────────────────────────────────────────────────────────

OLD_CSS = """      /* Top nav */
      .detail-topbar {
        flex-shrink: 0; display: flex; align-items: center;
        padding: 0 1.4rem; height: 58px; position: relative;
        background: linear-gradient(135deg, #162b12 0%, #2d5a27 100%);
        box-shadow: 0 2px 16px rgba(0,0,0,.35); gap: 1rem; z-index: 10;
      }
      .detail-brand { display: flex; align-items: center; gap: .55rem; text-decoration: none; flex-shrink: 0; }
      .detail-brand-logo { width: 32px; height: 32px; border-radius: 50%; border: 1.5px solid rgba(255,255,255,.25); object-fit: cover; }
      .detail-brand-name { font-size: .9rem; font-weight: 800; color: #c8e8c0; letter-spacing: .12em; text-transform: uppercase; }
      .detail-back-link {
        display: flex; align-items: center; gap: .4rem;
        color: #a8d5a0; font-size: .8rem; font-weight: 600; text-decoration: none;
        padding: .28rem .75rem; border-radius: 7px;
        border: 1px solid rgba(168,213,160,.3); background: rgba(255,255,255,.06);
        transition: all .15s; white-space: nowrap; margin-left: .5rem;
      }
      .detail-back-link:hover { background: rgba(255,255,255,.12); color: #d8f0d0; }
      .detail-topbar-title {
        flex: 1; font-size: 1.35rem; font-style: italic; color: #e8f8e0;
        font-family: Georgia, serif; font-weight: 700;
        text-align: left; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        margin: 0;
      }
      .detail-topbar-spacer { display: none; }"""

NEW_CSS = """      /* Top nav */
      .detail-topbar {
        flex-shrink: 0; display: flex; align-items: center;
        padding: 0 1.4rem; height: 54px;
        background: linear-gradient(135deg, #0f1f0d 0%, #1e4019 50%, #2d5a27 100%);
        box-shadow: 0 2px 18px rgba(0,0,0,.4); gap: 1rem; z-index: 10;
      }
      .detail-brand { display: flex; align-items: center; gap: .5rem; text-decoration: none; flex-shrink: 0; }
      .detail-brand-logo { width: 30px; height: 30px; border-radius: 50%; border: 1.5px solid rgba(184,224,176,.35); object-fit: cover; }
      .detail-brand-name { font-size: .85rem; font-weight: 800; color: #b8e0b0; letter-spacing: .14em; text-transform: uppercase; }
      .detail-back-link {
        display: flex; align-items: center; gap: .4rem;
        color: #90c888; font-size: .78rem; font-weight: 600; text-decoration: none;
        padding: .25rem .7rem; border-radius: 6px;
        border: 1px solid rgba(144,200,136,.25); background: rgba(255,255,255,.05);
        transition: all .15s; white-space: nowrap;
      }
      .detail-back-link:hover { background: rgba(255,255,255,.11); color: #c8f0c0; border-color: rgba(144,200,136,.5); }
      .detail-topbar-title { display: none; }
      .detail-topbar-spacer { display: none; }"""

content = rep(OLD_CSS, NEW_CSS, 'topbar CSS')

# ── 2. Identity panel CSS ────────────────────────────────────────────────────

OLD_ID = """      /* Stage 1 */
      #detail-overview { flex: 1; min-height: 0; display: flex; overflow: hidden; }

      /* Identity panel */
      .orchid-identity-panel {
        width: 340px; min-width: 260px; flex-shrink: 0;
        display: flex; flex-direction: column;
        background: #fff; border-right: 1px solid #cde3c8;
        overflow-y: auto; box-shadow: 2px 0 12px rgba(0,0,0,.07);
      }
      .oid-header {
        display: flex; align-items: center; gap: .6rem;
        padding: .9rem 1.2rem .75rem;
        background: linear-gradient(to right, #1a4a15, #2d6b27); flex-shrink: 0;
      }
      .oid-header-icon { width: 20px; height: 20px; flex-shrink: 0; opacity: .8; }
      .oid-subtitle { font-size: .72rem; font-weight: 800; color: #b8e0b0; letter-spacing: .12em; text-transform: uppercase; margin: 0; }
      .oid-photo-wrap { width: 100%; aspect-ratio: 4/3; overflow: hidden; background: #fff; flex-shrink: 0; }
      .oid-photo { width: 100%; height: 100%; object-fit: contain; display: block; }
      .oid-photo-placeholder { width: 100%; height: 100%; object-fit: contain; padding: 2.5rem; opacity: .55; }
      .oid-info { padding: 1.15rem 1.25rem 1.5rem; flex: 1; }
      .oid-sci-name { font-size: 1.18rem; font-style: italic; color: #143a10; margin: 0 0 .15rem; line-height: 1.3; font-weight: 800; font-family: Georgia, serif; }
      .oid-common-name { font-size: .88rem; color: #4a7a44; margin: 0 0 1.1rem; font-weight: 500; min-height: 1.2em; }
      .oid-field-list { display: flex; flex-direction: column; }
      .oid-field-row { display: flex; justify-content: space-between; align-items: flex-start; padding: .46rem 0; border-bottom: 1px solid #f0f5ef; gap: .5rem; }
      .oid-field-row:last-child { border-bottom: none; }
      .oid-field-sep { border-top: 2px solid #e0eedd; margin-top: .35rem; padding-top: .55rem; }
      .oid-field-label { font-size: .68rem; font-weight: 700; color: #5a8a54; text-transform: uppercase; letter-spacing: .08em; flex-shrink: 0; min-width: 42%; line-height: 1.4; padding-top: .05rem; }
      .oid-field-value { font-size: .84rem; font-weight: 500; color: #1c3d18; text-align: right; max-width: 58%; line-height: 1.4; }"""

NEW_ID = """      /* Stage 1 */
      #detail-overview { flex: 1; min-height: 0; display: flex; overflow: hidden; }

      /* Identity panel */
      .orchid-identity-panel {
        width: 320px; min-width: 240px; flex-shrink: 0;
        display: flex; flex-direction: column;
        background: #fafffe; border-right: 1.5px solid #c8e0c4;
        overflow-y: auto; box-shadow: 3px 0 16px rgba(0,0,0,.09);
      }
      .oid-header {
        display: flex; align-items: center; gap: .55rem;
        padding: .75rem 1.1rem .65rem;
        background: linear-gradient(135deg, #0f2a0c 0%, #1e4a19 60%, #2d6127 100%);
        flex-shrink: 0; border-bottom: 2px solid rgba(184,224,176,.2);
      }
      .oid-header-icon { width: 18px; height: 18px; flex-shrink: 0; opacity: .85; }
      .oid-subtitle { font-size: .65rem; font-weight: 800; color: #a8d8a0; letter-spacing: .15em; text-transform: uppercase; margin: 0; }
      .oid-photo-wrap { width: 100%; aspect-ratio: 4/3; overflow: hidden; background: #f5fbf4; flex-shrink: 0; border-bottom: 1px solid #daecd6; }
      .oid-photo { width: 100%; height: 100%; object-fit: contain; display: block; }
      .oid-photo-placeholder { width: 100%; height: 100%; object-fit: contain; padding: 2.5rem; opacity: .4; }
      .oid-info { padding: 1rem 1.1rem 1.4rem; flex: 1; }
      .oid-sci-name { font-size: 1.12rem; font-style: italic; color: #0d2e0a; margin: 0 0 .1rem; line-height: 1.3; font-weight: 800; font-family: Georgia, serif; }
      .oid-common-name { font-size: .82rem; color: #4a7a44; margin: 0 0 .9rem; font-weight: 500; }
      .oid-field-list { display: flex; flex-direction: column; border: 1px solid #e2eedf; border-radius: 8px; overflow: hidden; background: #fff; }
      .oid-field-row { display: flex; justify-content: space-between; align-items: flex-start; padding: .42rem .75rem; border-bottom: 1px solid #edf5eb; gap: .5rem; }
      .oid-field-row:last-child { border-bottom: none; }
      .oid-field-sep { border-top: 2px solid #d4ecd0; }
      .oid-field-label { font-size: .63rem; font-weight: 700; color: #4a7a44; text-transform: uppercase; letter-spacing: .09em; flex-shrink: 0; min-width: 44%; line-height: 1.4; padding-top: .08rem; }
      .oid-field-value { font-size: .82rem; font-weight: 500; color: #1a3818; text-align: right; max-width: 56%; line-height: 1.4; }"""

content = rep(OLD_ID, NEW_ID, 'identity panel CSS')

# ── 3. Map panel CSS ─────────────────────────────────────────────────────────

OLD_MAP = """      /* Map panel */
      .orchid-map-panel { flex: 1; display: flex; flex-direction: column; min-width: 0; }
      .orchid-map-subheader {
        flex-shrink: 0; display: flex; align-items: center;
        justify-content: space-between; padding: .55rem 1.1rem;
        background: #f0f9ed; border-bottom: 1px solid #cde3c8;
      }
      .map-subheader-left { display: flex; align-items: center; gap: .55rem; }
      .map-subheader-title { font-size: .75rem; font-weight: 700; color: #2d5a27; text-transform: uppercase; letter-spacing: .1em; }
      .map-subheader-sep { color: #9abf94; font-size: .8rem; }
      .map-subheader-loc { font-size: .78rem; color: #6a9a64; font-weight: 500; }
      .map-sightings-badge { font-size: .72rem; font-weight: 700; color: #1a4a15; background: #c8e8c0; padding: .22rem .75rem; border-radius: 12px; }
      #orchid-leaflet-map { flex: 1; }
      .orchid-map-hint { text-align: center; font-size: .78rem; color: #5a7a58; padding: .42rem 1rem; background: #f0f9ed; border-top: 1px solid #cde3c8; margin: 0; flex-shrink: 0; }"""

NEW_MAP = """      /* Map panel */
      .orchid-map-panel { flex: 1; display: flex; flex-direction: column; min-width: 0; }
      .orchid-map-name-bar {
        flex-shrink: 0; text-align: center;
        padding: .7rem 1.5rem .6rem;
        background: linear-gradient(to bottom, #f0f9ed, #f8fcf7);
        border-bottom: 1.5px solid #c8e0c4;
      }
      .orchid-map-orchid-name {
        font-size: 1.45rem; font-style: italic; color: #0d2e0a;
        font-family: Georgia, serif; font-weight: 800; margin: 0;
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
      }
      .orchid-map-subheader {
        flex-shrink: 0; display: flex; align-items: center;
        justify-content: space-between; padding: .38rem 1.1rem;
        background: #eaf5e7; border-bottom: 1px solid #c8e0c4;
      }
      .map-subheader-left { display: flex; align-items: center; gap: .5rem; }
      .map-subheader-title { font-size: .68rem; font-weight: 700; color: #2a5224; text-transform: uppercase; letter-spacing: .1em; }
      .map-subheader-sep { color: #9abf94; font-size: .75rem; }
      .map-subheader-loc { font-size: .72rem; color: #5a8a54; font-weight: 500; }
      .map-sightings-badge { font-size: .68rem; font-weight: 700; color: #143a10; background: #b8e0b0; padding: .18rem .65rem; border-radius: 10px; letter-spacing: .02em; }
      #orchid-leaflet-map { flex: 1; }
      .orchid-map-hint { text-align: center; font-size: .75rem; color: #5a7a58; padding: .35rem 1rem; background: #eaf5e7; border-top: 1px solid #c8e0c4; margin: 0; flex-shrink: 0; }"""

content = rep(OLD_MAP, NEW_MAP, 'map panel CSS')

# ── 4. Add orchid name bar to map panel HTML ──────────────────────────────────

OLD_MAP_HTML = """      <!-- Right: Map Panel -->
      <div class="orchid-map-panel">
        <div class="orchid-map-subheader">"""

NEW_MAP_HTML = """      <!-- Right: Map Panel -->
      <div class="orchid-map-panel">
        <div class="orchid-map-name-bar">
          <p id="oid-map-orchid-name" class="orchid-map-orchid-name">—</p>
        </div>
        <div class="orchid-map-subheader">"""

content = rep(OLD_MAP_HTML, NEW_MAP_HTML, 'map panel HTML: orchid name bar')

# ── 5. Remove name from topbar HTML (keep element for JS compat, just hidden) ─

OLD_TOPBAR_NAME = '      <p id="detail-topbar-name" class="detail-topbar-title">Orchid Detail</p>\n      <div class="detail-topbar-spacer"></div>'
NEW_TOPBAR_NAME = ''
content = rep(OLD_TOPBAR_NAME, NEW_TOPBAR_NAME, 'topbar: remove name element')

# ── 6. Update populateIdentityPanel to set map name + fix topbar-name safely ──

OLD_POP = "        document.getElementById('detail-topbar-name').textContent = orchidName;"
NEW_POP = """        const topbarNameEl = document.getElementById('detail-topbar-name');
        if (topbarNameEl) topbarNameEl.textContent = orchidName;
        const mapOrchidNameEl = document.getElementById('oid-map-orchid-name');
        if (mapOrchidNameEl) mapOrchidNameEl.textContent = orchidName;"""
content = rep(OLD_POP, NEW_POP, 'JS: populate map orchid name')

# ── 7. Back link: always catalog ──────────────────────────────────────────────

OLD_BACK = """        // Update back link based on referrer page
        const fromPage = params.get('from') || '';
        const backLink = document.getElementById('detail-back-link');
        if (backLink) {
          if (fromPage === 'researcher-dashboard') {
            backLink.href = 'researcher-dashboard.html';
            backLink.innerHTML = '&larr; Dashboard';
          } else if (fromPage === 'denr-dashboard') {
            backLink.href = 'denr-dashboard.html';
            backLink.innerHTML = '&larr; Dashboard';
          } else {
            backLink.href = 'catalog.html';
            backLink.innerHTML = '&larr; Catalog';
          }
        }"""
NEW_BACK = """        // Back link always returns to catalog
        const backLink = document.getElementById('detail-back-link');
        if (backLink) { backLink.href = 'catalog.html'; backLink.innerHTML = '&larr; Catalog'; }"""
content = rep(OLD_BACK, NEW_BACK, 'JS: back link always catalog')

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'w', encoding='utf-8') as f:
    f.write(content)
print('\nDone.')
