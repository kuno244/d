import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
r=json.loads((ROOT/'registry/asset_registry.json').read_text()); ids=[a['asset_id'] for a in r['assets']]
assert len(ids)==34 and len(ids)==len(set(ids))
static=[a for a in r['assets'] if a['category'] in ('BUILDING','WORLD_OBJECT','DECORATION')]
assert len(static)==14 and all(a.get('shipping_status')=='READY_STATIC_MOBILE' for a in static)
manifest=json.loads((ROOT/'registry/shipping_manifest.json').read_text())
assert manifest['shipping_asset_count']==14 and manifest['shipping_lod_file_count']==42
for a in manifest['shipping_assets']:
    for p in a['lods'].values():
        assert p.startswith('assets/mobile/') and '/source/' not in p and '/processed/' not in p
print('PASS asset contract')
