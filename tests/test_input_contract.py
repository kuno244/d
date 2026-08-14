from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'scripts/city/strategy_camera.gd'
assert p.exists(),'strategy_camera.gd missing'
s=p.read_text()
assert 'camera_left' in s and 'camera_right' in s
assert 'Vector2(-1.0, 0.0)' in s or 'Vector2(-1, 0)' in s
assert 'Vector2(1.0, 0.0)' in s or 'Vector2(1, 0)' in s
assert 'InputEventScreenDrag' in s and 'InputEventMagnifyGesture' in s
print('PASS input contract')
