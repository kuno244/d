import json,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from save_contract import default_save, validate_save, migrate_save, atomic_write_json, recover_json
s=default_save(now=1000)
assert s['save_version']==3
for k in ['capacities','troop_state','research_state','modifiers']:
    assert k in s and isinstance(s[k], (dict,list)),k
city=s['city_state']
for k in ['buildings','decorations','construction_queues','construction_queue','production','population','city_power']:
    assert k in city,k
assert city['buildings'] and city['buildings'][0]['building_id']=='building_royal_citadel'
assert city['buildings'][0]['state']=='ACTIVE' and city['buildings'][0]['level']==1
assert validate_save(s)==[]
# v1 migration preserves old values, adds all DEVELOPMENT 04 state, then reaches v3.
v1={
 'save_version':1,'profile':{'created_at':5},
 'resources':{'food':123,'wood':456,'stone':78,'gold':9},
 'city_state':{'buildings':[],'training_queues':[],'research_queue':[]},
 'progression':{'account_level':2},'world_state':{'season_id':'preseason_01'}}
m=migrate_save(v1,now=2000)
assert m['save_version']==3 and m['resources']['food']==123 and m['progression']['account_level']==2
assert 'capacities' in m and 'troop_state' in m and 'research_state' in m
# Corrupted timestamps are sanitized: no negative/far-future active timers.
m['city_state']['construction_queue']={'finish_timestamp':-999,'start_timestamp':999999999999,'state':'ACTIVE_QUEUE'}
m2=migrate_save(m,now=3000)
q=m2['city_state']['construction_queue']; assert q is None or (0<=q['start_timestamp']<=3000 and q['finish_timestamp']>=q['start_timestamp'])

# Corrupted dynamic values are normalized without introducing invalid queue entries.
bad=default_save(now=1000)
bad['city_state']['construction_queues']=['invalid',{'start_timestamp':-5,'finish_timestamp':999999999999,'state':'ACTIVE_QUEUE'}]
bad['troop_state']['inventory']={'troop_kingdom_swordsman':-9}
bad['troop_state']['training_queues']=['invalid',{'start_timestamp':-3,'finish_timestamp':999999999999,'state':'TRAINING'}]
bad['research_state']['progress']={'research_agricultural_methods':-4}
clean=migrate_save(bad,now=3000)
assert all(isinstance(q,dict) for q in clean['city_state']['construction_queues'])
assert all(isinstance(q,dict) for q in clean['troop_state']['training_queues'])
assert clean['troop_state']['inventory']['troop_kingdom_swordsman']==0
assert clean['research_state']['progress']['research_agricultural_methods']==0

with tempfile.TemporaryDirectory() as td:
    p=Path(td)/'save.json'; atomic_write_json(p,s); assert json.loads(p.read_text())['save_version']==3
    p.write_text('{bad'); Path(str(p)+'.bak').write_text(json.dumps(s)); assert recover_json(p)['save_version']==3
print('PASS dev04 save fields through v3 migration')
