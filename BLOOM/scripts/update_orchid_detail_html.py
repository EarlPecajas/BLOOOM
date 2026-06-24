with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Update top bar HTML
old_topbar = '''    <!-- Top navigation bar -->
    <div class="detail-topbar">
      <a href="catalog.html" class="detail-back-link">&larr; Catalog</a>
      <p id="detail-topbar-name" class="detail-topbar-title">Orchid Detail</p>
      <div class="detail-topbar-right"></div>
    </div>'''

new_topbar = '''    <!-- Top navigation bar -->
    <div class="detail-topbar">
      <a href="index.html" class="detail-brand">
        <img src="./loo.png" alt="BLOOM" class="detail-brand-logo">
        <span class="detail-brand-name">BLOOM</span>
      </a>
      <a href="catalog.html" class="detail-back-link">&larr; Catalog</a>
      <p id="detail-topbar-name" class="detail-topbar-title">Orchid Detail</p>
      <div class="detail-topbar-spacer"></div>
    </div>'''

# Update identity panel header with SVG leaf icon
old_oid_header = '''        <div class="oid-header">
          <span class="oid-subtitle">Orchid Identity</span>
        </div>'''

new_oid_header = '''        <div class="oid-header">
          <svg class="oid-header-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 2C9 2 4 6 4 12c0 4 2.5 7.5 8 9.5C18 19.5 20 16 20 12c0-6-5-10-8-10z" fill="rgba(184,224,176,.6)" stroke="#b8e0b0" stroke-width="1.2"/>
            <path d="M12 21.5V10M12 10C10 8 7 8 6 10M12 10C14 8 17 8 18 10" stroke="#b8e0b0" stroke-width="1.2" stroke-linecap="round"/>
          </svg>
          <span class="oid-subtitle">Orchid Identity</span>
        </div>'''

# Update map panel to add subheader
old_map_panel = '''      <!-- Right: Map Panel -->
      <div class="orchid-map-panel">
        <div id="orchid-leaflet-map"></div>
        <p class="orchid-map-hint">Click an orchid icon on the map to view sighting details</p>
      </div>'''

new_map_panel = '''      <!-- Right: Map Panel -->
      <div class="orchid-map-panel">
        <div class="orchid-map-subheader">
          <div class="map-subheader-left">
            <span class="map-subheader-title">Sighting Locations</span>
            <span class="map-subheader-sep">&middot;</span>
            <span class="map-subheader-loc">Mt. Busa, Sarangani</span>
          </div>
          <span class="map-sightings-badge" id="map-sightings-count">5 sightings</span>
        </div>
        <div id="orchid-leaflet-map"></div>
        <p class="orchid-map-hint">Click an orchid icon on the map to view sighting details</p>
      </div>'''

for old, new in [(old_topbar, new_topbar), (old_oid_header, new_oid_header), (old_map_panel, new_map_panel)]:
    if old in content:
        content = content.replace(old, new, 1)
        print(f'Replaced: {old[:50].strip()}...')
    else:
        print(f'NOT FOUND: {old[:60].strip()}')

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')