import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
reg=json.loads((ROOT/'registry/asset_registry.json').read_text())
ids={a['asset_id'] for a in reg['assets']}
expected={'resources':4,'buildings':10,'troops':5,'heroes':10,'pve':5}
for name,count in expected.items():
    p=ROOT/f'data/{name}/{name}.json'
    assert p.exists(), str(p)
    d=json.loads(p.read_text())
    assert len(d['items'])==count,(name,len(d['items']))
    for x in d['items']:
        if 'asset_id' in x: assert x['asset_id'] in ids,(name,x['asset_id'])
heroes=json.loads((ROOT/'data/heroes/heroes.json').read_text())['items']
assert any(h['asset_id']=='hero_fire_mage_001' for h in heroes)
assert not any(h.get('asset_id')=='hero_fire_mage_001' and 'Lyra' in h.get('display_name','') for h in heroes)
print('PASS data contract')
