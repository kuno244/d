import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from dev04_logic_reference import Economy, training_quote, start_training, complete_training
tr={x['id']:x for x in json.loads((ROOT/'data/troops/troops.json').read_text())['items']}
sword=tr['troop_kingdom_swordsman']; cav=tr['troop_royal_cavalry']
cost,dur=training_quote(sword,10,0.0)
assert cost['food']==sword['base_training_cost']['food']*10 and dur==sword['base_training_time_sec']*10
e=Economy({k:99999 for k in ['food','wood','stone','gold']},{k:999999 for k in ['food','wood','stone','gold']})
assert start_training(e,cav,5,1,4,50,1000,0.0) is None # Citadel locked
entry=start_training(e,sword,10,1,2,40,1000,0.25)
assert entry and entry['amount']==10 and entry['finish_timestamp']>1000
inv={}
assert not complete_training(entry,entry['finish_timestamp']-1,inv)
assert complete_training(entry,entry['finish_timestamp'],inv)
assert inv[sword['id']]==10 and entry['state']=='COMPLETE'
assert not complete_training(entry,entry['finish_timestamp']+1,inv) # no duplicate
assert start_training(e,sword,41,1,2,40,1000,0.0) is None # capacity
print('PASS dev04 training logic')
