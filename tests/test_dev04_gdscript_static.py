import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from validate_gdscript_static import validate
r=validate(ROOT)
assert r['passed'],r['errors']
assert r['gdscript_files'] >= 20
assert r['scene_files'] >= 5
assert r['duplicate_class_names']==0
assert r['duplicate_functions']==0
assert r['missing_res_paths']==0
assert r['forbidden_runtime_refs']==0
print('PASS dev04 GDScript static validation',r['gdscript_files'],r['scene_files'])
