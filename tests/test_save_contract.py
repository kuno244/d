import json,tempfile,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from save_contract import default_save,validate_save,migrate_save,atomic_write_json,recover_json
s=default_save(now=1000); assert validate_save(s)==[]; assert s['save_version']==3
# Historical v0 -> v1 -> v2 -> v3 path remains supported.
old={'save_version':0,'profile':{},'resources':{'food':1000,'wood':1000,'stone':500,'gold':250},'city_state':{'buildings':[],'training_queues':[],'research_queue':[]},'progression':{},}
m=migrate_save(old,now=2000); assert m['save_version']==3 and 'world_state' in m and 'capacities' in m
# Explicit DEVELOPMENT 03 v1 migration remains supported.
v1={'save_version':1,'profile':{},'resources':{'food':321,'wood':222,'stone':111,'gold':55},'city_state':{'buildings':[],'training_queues':[],'research_queue':[]},'progression':{},'world_state':{}}
m1=migrate_save(v1,now=2000); assert m1['save_version']==3 and m1['resources']['food']==321 and m1['city_state']['buildings']
with tempfile.TemporaryDirectory() as td:
    p=Path(td)/'save.json'; atomic_write_json(p,s); assert json.loads(p.read_text())['save_version']==3
    p.write_text('{broken'); backup=Path(str(p)+'.bak'); backup.write_text(json.dumps(s))
    recovered=recover_json(p); assert recovered['save_version']==3
print('PASS save contract')
