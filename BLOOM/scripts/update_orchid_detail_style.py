import re

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'r', encoding='utf-8') as f:
    content = f.read()

new_style = """    <style>
      html, body { height: 100%; margin: 0; overflow: hidden; }
      body { display: flex; flex-direction: column; background: #eaf4e7; font-family: Inter, Roboto, sans-serif; }

      /* Top nav */
      .detail-topbar {
        flex-shrink: 0; display: flex; align-items: center;
        padding: 0 1.4rem; height: 58px;
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
        flex: 1; font-size: 1rem; font-style: italic; color: #e8f8e0;
        font-family: Georgia, serif; font-weight: 700;
        text-align: center; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
      }
      .detail-topbar-spacer { min-width: 160px; }

      /* Stage 1 */
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
      .oid-photo-wrap { width: 100%; aspect-ratio: 16/10; overflow: hidden; background: #eaf4e7; flex-shrink: 0; }
      .oid-photo { width: 100%; height: 100%; object-fit: cover; display: block; transition: transform .4s; }
      .oid-photo:hover { transform: scale(1.04); }
      .oid-photo-placeholder { width: 100%; height: 100%; object-fit: contain; padding: 2rem; opacity: .28; }
      .oid-info { padding: 1.15rem 1.25rem 1.5rem; flex: 1; }
      .oid-sci-name { font-size: 1.18rem; font-style: italic; color: #143a10; margin: 0 0 .15rem; line-height: 1.3; font-weight: 800; font-family: Georgia, serif; }
      .oid-common-name { font-size: .88rem; color: #4a7a44; margin: 0 0 1.1rem; font-weight: 500; min-height: 1.2em; }
      .oid-meta-table { border: 1px solid #daecd6; border-radius: 10px; overflow: hidden; margin-bottom: 1.1rem; background: #f8fcf7; box-shadow: 0 1px 4px rgba(0,0,0,.04); }
      .oid-meta-row { display: flex; justify-content: space-between; align-items: center; padding: .55rem .95rem; border-bottom: 1px solid #eaf3e8; }
      .oid-meta-row:last-child { border-bottom: none; }
      .oid-meta-label { color: #5a8a54; font-weight: 700; font-size: .68rem; text-transform: uppercase; letter-spacing: .09em; flex-shrink: 0; }
      .oid-meta-value { color: #1c3d18; font-weight: 600; font-size: .85rem; text-align: right; max-width: 65%; }
      .oid-badges { display: flex; gap: .45rem; flex-wrap: wrap; }
      .oid-badge { padding: .32rem .9rem; border-radius: 20px; font-size: .74rem; font-weight: 700; letter-spacing: .04em; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
      .oid-badge-status { background: #fff3cd; color: #664d03; }
      .oid-badge-status.critical { background: #f8d7da; color: #842029; }
      .oid-badge-status.endangered { background: #fce4d6; color: #9c3a0a; }
      .oid-badge-status.vulnerable { background: #fff3cd; color: #664d03; }
      .oid-badge-status.least-concern { background: #d1e7dd; color: #0f5132; }
      .oid-badge-confidence { background: #dbeafe; color: #1e40af; }

      /* Map panel */
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
      .orchid-map-hint { text-align: center; font-size: .78rem; color: #5a7a58; padding: .42rem 1rem; background: #f0f9ed; border-top: 1px solid #cde3c8; margin: 0; flex-shrink: 0; }

      /* Stage 2: paged detail */
      #detail-paged { flex: 1; min-height: 0; display: flex; flex-direction: column; overflow: hidden; background: #fff; }
      .orchid-detail-header-bar {
        display: flex; align-items: center; justify-content: space-between;
        padding: .75rem 1.3rem; border-bottom: 1.5px solid #d8ecd6;
        background: linear-gradient(to right, #f0f9ed, #f8fcf7);
        flex-shrink: 0; gap: .75rem; box-shadow: 0 1px 6px rgba(0,0,0,.06);
      }
      .orchid-detail-back-btn {
        background: #fff; border: 1.5px solid #b8d8b4; border-radius: 8px;
        padding: .32rem .9rem; font-size: .82rem; font-weight: 700; color: #2d5a27;
        cursor: pointer; white-space: nowrap; transition: all .15s; box-shadow: 0 1px 4px rgba(0,0,0,.06);
      }
      .orchid-detail-back-btn:hover { background: #e8f3e6; border-color: #2d5a27; }
      .orchid-detail-header-name { font-size: 1rem; font-style: italic; color: #143a10; font-weight: 700; margin: 0; flex: 1; text-align: center; font-family: Georgia, serif; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .orchid-step-bar { display: flex; align-items: center; justify-content: space-between; padding: .5rem 1.3rem; background: #fff; border-bottom: 1px solid #ecf3eb; flex-shrink: 0; }
      .orchid-step-label-text { font-size: .8rem; font-weight: 600; color: #3e6639; }
      .orchid-step-badge { font-size: .73rem; font-weight: 700; color: #2d5a27; background: #d4eed0; padding: .18rem .7rem; border-radius: 12px; }
      .orchid-detail-pages-wrap { flex: 1; overflow-y: auto; min-height: 0; }
      .detail-step-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #b8d9b2; transition: all .2s; }
      .detail-step-dot.active { background: #2d5a27; transform: scale(1.4); }
      .orchid-detail-page .orchid-detail-row { display: flex; justify-content: space-between; align-items: flex-start; padding: .8rem 1.4rem; border-bottom: 1px solid #f0f5ef; gap: 1.5rem; }
      .orchid-detail-page .orchid-detail-row:nth-child(even) { background: #f9fcf8; }
      .orchid-detail-page .orchid-detail-row[hidden] { display: none; }
      .orchid-detail-page .orchid-detail-label { color: #4a7a44; font-weight: 700; font-size: .72rem; min-width: 150px; flex-shrink: 0; text-transform: uppercase; letter-spacing: .07em; line-height: 1.35; padding-top: .1rem; }
      .orchid-detail-page .orchid-detail-row span:not(.orchid-detail-label) { color: #162b14; font-weight: 500; font-size: .95rem; text-align: right; line-height: 1.5; }
      .orchid-nav-bar { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1.3rem; border-top: 1.5px solid #d8ecd6; background: linear-gradient(to right, #f0f9ed, #f8fcf7); flex-shrink: 0; }
      .orchid-nav-btn { padding: .45rem 1.3rem; border-radius: 8px; font-size: .85rem; font-weight: 700; cursor: pointer; border: 1.5px solid #2d5a27; transition: all .15s; box-shadow: 0 1px 4px rgba(0,0,0,.06); }
      .orchid-nav-btn-outline { background: #fff; color: #2d5a27; }
      .orchid-nav-btn-outline:hover { background: #e8f3e6; }
      .orchid-nav-btn-fill { background: #2d5a27; color: #fff; border-color: #2d5a27; }
      .orchid-nav-btn-fill:hover { background: #1e3d1a; }
    </style>"""

# Replace style block
content = re.sub(r'    <style>.*?    </style>', new_style, content, count=1, flags=re.DOTALL)

with open(r'c:\Users\pecaj\Downloads\BLOOM\frontend\orchid-detail.html', 'w', encoding='utf-8') as f:
    f.write(content)
print('Style block replaced')