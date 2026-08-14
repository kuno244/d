from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files=list((ROOT/'scenes').rglob('*'))+list((ROOT/'scripts').rglob('*'))+list((ROOT/'data').rglob('*'))
for p in files:
    if not p.is_file(): continue
    try: s=p.read_text(encoding='utf-8').lower()
    except UnicodeDecodeError: continue
    for bad in ['assets/source/','assets/processed/','meshy_ai_model.glb']:
        assert bad not in s, f'{bad} referenced by {p.relative_to(ROOT)}'
print('PASS no raw runtime references')
