import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
checked=0
for path in list(ROOT.rglob('*.tscn'))+list(ROOT.rglob('*.gd')):
    if '/assets/source/' in str(path) or '/assets/processed/' in str(path):
        continue
    text=path.read_text(encoding='utf-8')
    for rel in re.findall(r'res://[A-Za-z0-9_./-]+', text):
        clean=rel.rstrip('"\' )],}')
        target=ROOT/clean[len('res://'):]
        assert target.exists(), f'{path.relative_to(ROOT)} -> missing {clean}'
        checked += 1
print('PASS resource references',checked)
