from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
roots=['project.godot','scripts','scenes','data']
for item in roots:
    p=ROOT/item
    files=[p] if p.is_file() else list(p.rglob('*'))
    for f in files:
        if not f.is_file(): continue
        try: s=f.read_text(encoding='utf-8').lower()
        except UnicodeDecodeError: continue
        for forbidden in ['audiomanager','audiostream','music_volume','sfx_volume','voice_volume','placeholder beep']:
            assert forbidden not in s, f'{forbidden} in {f.relative_to(ROOT)}'
print('PASS audio excluded from runtime scope')
