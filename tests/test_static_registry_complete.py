import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
r=json.loads((ROOT/'registry/asset_registry.json').read_text())
static=[a for a in r['assets'] if a['category'] in ('BUILDING','WORLD_OBJECT','DECORATION')]
assert len(static)==14
for a in static:
    assert set((a.get('lods') or {}).keys()) == {'LOD0','LOD1','LOD2'}, a['asset_id']
    assert a.get('quality_gate_status') == 'PASS', a['asset_id']
    assert a.get('shipping_status') == 'READY_STATIC_MOBILE', a['asset_id']
    c=a.get('collision')
    assert c is not None, a['asset_id']
    assert c.get('collision_mesh_triangles',0) <= 500, a['asset_id']
print('PASS static registry',len(static))
