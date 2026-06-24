import pathlib

path = pathlib.Path(r'C:\Users\pecaj\Downloads\BLOOM3D\BLOOM\frontend\catalog.html')
text = path.read_text(encoding='utf-8')

si = text.find('      function orchidGoToDetailPage(n) {')
ei = text.find('      function closeOrchidDetails() {')

js_path = pathlib.Path(r'C:\Users\pecaj\Downloads\BLOOM3D\new_js_block.txt')
new_js = js_path.read_text(encoding='utf-8')

new_text = text[:si] + new_js + text[ei:]
path.write_text(new_text, encoding='utf-8')
print('Done start=%d end=%d newlen=%d' % (si, ei, len(new_text)))
