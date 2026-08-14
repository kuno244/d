import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from shipping_gate import validate_project
report=validate_project(ROOT)
assert report['passed'], report['errors']
assert report['checked_mobile_lods']==42, report['checked_mobile_lods']
assert report['shipping_assets']==14, report['shipping_assets']
assert report['raw_only_assets']==20, report['raw_only_assets']
assert report['development_phase']=='DEVELOPMENT_04', report['development_phase']
print('PASS shipping gate contract', report['checked_mobile_lods'])
