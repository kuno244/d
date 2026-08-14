import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from dev04_logic_reference import Economy, can_upgrade, start_construction, complete_construction, cancel_construction
buildings={x['id']:x for x in json.loads((ROOT/'data/buildings/buildings.json').read_text())['items']}
farm=buildings['building_farm']
e=Economy({'food':999999,'wood':999999,'stone':999999,'gold':999999},{k:9999999 for k in ['food','wood','stone','gold']})
inst={'instance_id':'farm01','building_id':'building_farm','level':1,'state':'ACTIVE'}
assert can_upgrade(farm,1,2,9999)
assert not can_upgrade(farm,1,1,9999)
q=start_construction(e,farm,inst,2,1000,None,9999,2,0.0)
assert q and inst['level']==1 and inst['state']=='UPGRADING' and q['target_level']==2 and q['finish_timestamp']>1000
assert complete_construction(inst,q,q['finish_timestamp']-1)==False and inst['level']==1
assert complete_construction(inst,q,q['finish_timestamp'])==True and inst['level']==2 and inst['state']=='ACTIVE'
# Queue exclusivity and invalid > max level.
q2=start_construction(e,farm,inst,3,2000,{'type':'UPGRADE'},9999,3,0.0)
assert q2 is None
inst['level']=20
assert not can_upgrade(farm,20,20,999999)
# Cancel does not level up and refund is atomic.
inst={'instance_id':'farm02','building_id':'building_farm','level':1,'state':'ACTIVE'}
before=dict(e.resources); q=start_construction(e,farm,inst,2,3000,None,9999,2,0.0); after_spend=dict(e.resources)
assert cancel_construction(e,inst,q,0.5)
assert inst['level']==1 and inst['state']=='ACTIVE'
assert all(after_spend[k] <= e.resources[k] <= before[k] for k in before)
print('PASS dev04 construction logic')
