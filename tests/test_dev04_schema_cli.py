import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from validate_dev04_schema import validate
r=validate(ROOT)
assert r['passed'],r['errors']
assert r['buildings']==10 and r['building_levels']==200
assert r['research_nodes']==20 and r['research_dag_acyclic']
assert r['troops']==5 and r['resources']==4
assert r['save_version']==4
print('PASS dev04 schema cli',r['building_levels'],r['research_nodes'])
