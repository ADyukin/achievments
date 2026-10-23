"""Rebuild the offline preview using original app assets. Python stdlib only."""
import base64
from pathlib import Path
root = Path(__file__).resolve().parent
app = root.parent / 'AchievementDemo'
def data(path, mime):
    return 'data:' + mime + ';base64,' + base64.b64encode(path.read_bytes()).decode()
html = (root / 'preview.template.html').read_text()
for token, path, mime in [
    ('__FONT__', app / 'Fonts/Onest.ttf', 'font/ttf'),
    ('__BADGE__', app / 'Assets.xcassets/AchievementBadge.imageset/badge.png', 'image/png'),
    ('__PERFUME__', app / 'Assets.xcassets/ProductPerfume.imageset/perfume.png', 'image/png'),
]:
    html = html.replace(token, data(path, mime))
(root / 'index.html').write_text(html)
print('Built standalone index.html')
