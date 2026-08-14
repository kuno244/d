#!/usr/bin/env python3
from __future__ import annotations
import io, json, struct, sys
from pathlib import Path
from PIL import Image

TRI_LIMITS={
 'BUILDING': {'LOD0':85000,'LOD1':50000,'LOD2':20000},
 'WORLD_OBJECT': {'LOD0':55000,'LOD1':26000,'LOD2':11000},
 'DECORATION': {'LOD0':20000,'LOD1':10000,'LOD2':4000},
}
TEXTURE_LIMITS={
 'BUILDING': {'LOD0':2048,'LOD1':1024,'LOD2':512},
 'WORLD_OBJECT': {'LOD0':1024,'LOD1':1024,'LOD2':512},
 'DECORATION': {'LOD0':1024,'LOD1':512,'LOD2':512},
}
STATIC_CATEGORIES=set(TRI_LIMITS)

def glb_info(path: Path) -> dict:
    with path.open('rb') as f:
        head=f.read(12)
        if len(head)!=12 or head[:4]!=b'glTF':
            raise ValueError(f'not GLB: {path}')
        total=struct.unpack_from('<I',head,8)[0]
        chunks=[]
        while f.tell()<total:
            hdr=f.read(8)
            if len(hdr)<8: break
            ln,typ=struct.unpack('<II',hdr)
            chunks.append((typ,f.read(ln)))
    tree=json.loads(next(data for typ,data in chunks if typ==0x4E4F534A).rstrip(b' \t\r\n\0'))
    binchunk=next((data for typ,data in chunks if typ==0x004E4942),b'')
    tris=0
    for mesh in tree.get('meshes',[]):
        for prim in mesh.get('primitives',[]):
            if 'indices' in prim:
                tris += int(tree['accessors'][prim['indices']]['count'])//3
            else:
                pos=prim.get('attributes',{}).get('POSITION')
                if pos is not None: tris += int(tree['accessors'][pos]['count'])//3
    images=[]
    for image in tree.get('images',[]):
        if 'bufferView' not in image: continue
        bv=tree['bufferViews'][image['bufferView']]
        start=int(bv.get('byteOffset',0)); end=start+int(bv['byteLength'])
        try:
            with Image.open(io.BytesIO(binchunk[start:end])) as pic:
                images.append({'width':pic.width,'height':pic.height,'format':pic.format})
        except Exception:
            images.append({'width':None,'height':None,'format':'unreadable'})
    return {'triangles':tris,'images':images,'size_bytes':path.stat().st_size}

def validate_project(root: Path|str) -> dict:
    root=Path(root)
    errors=[]; warnings=[]; checked=[]
    reg=json.loads((root/'registry/asset_registry.json').read_text())
    manifest=json.loads((root/'registry/shipping_manifest.json').read_text())
    assets=reg.get('assets',[])
    ids=[a.get('asset_id') for a in assets]
    byid={a.get('asset_id'):a for a in assets}
    if len(ids)!=34: errors.append(f'asset registry count {len(ids)} != 34')
    if len(ids)!=len(set(ids)): errors.append('duplicate asset_id')
    for marker in ('assets/source/.gdignore','assets/processed/.gdignore'):
        if not (root/marker).exists(): errors.append(f'missing isolation marker {marker}')

    shipping_assets=manifest.get('shipping_assets',[])
    manifest_ids=[a.get('asset_id') for a in shipping_assets]
    if len(manifest_ids)!=len(set(manifest_ids)): errors.append('duplicate asset_id in shipping manifest')
    if any(aid not in byid for aid in manifest_ids):
        errors.extend(f'manifest references missing asset id: {aid}' for aid in manifest_ids if aid not in byid)

    expected_static={a['asset_id'] for a in assets if a.get('category') in STATIC_CATEGORIES and a.get('shipping_status')=='READY_STATIC_MOBILE'}
    if set(manifest_ids)!=expected_static:
        errors.append('shipping manifest asset set does not equal READY_STATIC_MOBILE registry set')

    for entry in shipping_assets:
        aid=entry['asset_id']; source=byid.get(aid,{})
        cat=source.get('category')
        if cat not in STATIC_CATEGORIES:
            errors.append(f'{aid}: non-static asset in shipping manifest')
            continue
        lods=entry.get('lods',{})
        if set(lods)!={'LOD0','LOD1','LOD2'}:
            errors.append(f'{aid}: shipping manifest must contain LOD0/LOD1/LOD2')
        for tier,rel in lods.items():
            if not isinstance(rel,str) or not rel.startswith('assets/mobile/') or '/source/' in rel or '/processed/' in rel:
                errors.append(f'{aid} {tier}: invalid shipping path {rel}')
                continue
            path=root/rel
            if not path.exists():
                errors.append(f'{aid} {tier}: missing file {rel}')
                continue
            info=glb_info(path); checked.append((aid,tier,info))
            limit=TRI_LIMITS[cat][tier]
            if info['triangles']>limit:
                errors.append(f"{aid} {tier}: {info['triangles']} tris > {limit}")
            tex_limit=TEXTURE_LIMITS[cat][tier]
            for im in info['images']:
                if im['width'] is None or im['height'] is None:
                    errors.append(f'{aid} {tier}: unreadable embedded texture')
                elif max(im['width'],im['height'])>tex_limit:
                    errors.append(f"{aid} {tier}: {im['width']}x{im['height']} texture > {tex_limit}")
        collision=entry.get('collision', source.get('collision',{})) or {}
        if int(collision.get('collision_mesh_triangles',0))>500:
            errors.append(f'{aid}: collision mesh too heavy')

    # Character visuals must remain outside shipping while raw/unrigged.
    for a in assets:
        cat=a.get('category')
        if cat in ('HERO','TROOP','PVE_CREATURE'):
            if a.get('asset_id') in manifest_ids:
                errors.append(f"{a['asset_id']}: RAW/unrigged character leaked into shipping")
            if a.get('shipping_status','').startswith('BLOCKED_'):
                warnings.append(f"{a['asset_id']}: RAW_ONLY data entity")

    # Catch any unexpected mobile GLB not declared by the manifest.
    declared={root/rel for entry in shipping_assets for rel in entry.get('lods',{}).values()}
    actual=set((root/'assets/mobile').rglob('*.glb'))
    undeclared=sorted(str(p.relative_to(root)) for p in actual-declared)
    missing=sorted(str(p.relative_to(root)) for p in declared-actual)
    if undeclared: errors.append('undeclared mobile GLBs: '+', '.join(undeclared))
    if missing: errors.append('manifest GLBs missing on disk: '+', '.join(missing))

    report={
        'development_phase':str(manifest.get('development_phase','UNKNOWN')),
        'shipping_assets':len(shipping_assets),
        'checked_mobile_lods':len(checked),
        'raw_only_assets':sum(1 for a in assets if a.get('shipping_status','').startswith('BLOCKED_')),
        'errors':errors,
        'warnings':warnings,
        'passed':not errors,
    }
    reports=root/'reports'; reports.mkdir(parents=True,exist_ok=True)
    (reports/'shipping_gate_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    return report

def main() -> int:
    root=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
    report=validate_project(root)
    print(json.dumps(report,indent=2))
    return 0 if report['passed'] else 2

if __name__=='__main__':
    raise SystemExit(main())
