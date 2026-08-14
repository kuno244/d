from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'project.godot'
assert p.exists(), 'project.godot missing'
s=p.read_text()
for name in ['GameState','DataRegistry','SaveService','SceneRouter','GameClock','EventHub']:
    assert f'{name}=' in s or f'{name}="' in s, name
for forbidden in ['AudioManager','music_volume','sfx_volume','voice_volume']:
    assert forbidden.lower() not in s.lower(), forbidden
assert 'run/main_scene="res://scenes/boot/Boot.tscn"' in s
print('PASS project contract')
