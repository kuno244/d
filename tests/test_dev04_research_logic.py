import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from dev04_logic_reference import Economy, can_research, research_quote, start_research, complete_research, aggregate_modifiers, apply_modifier
nodes={x['id']:x for x in json.loads((ROOT/'data/research/research.json').read_text())['items']}
ag=nodes['research_agricultural_methods']; lumber=nodes['research_lumber_processing']
assert not can_research(ag,{},1,2)  # Academy alone cannot bypass Citadel research-tier gate.
assert can_research(ag,{},1,3)
assert not can_research(lumber,{},3,5)
progress={'research_agricultural_methods':1}
assert not can_research(lumber,progress,3,4)
assert can_research(lumber,progress,3,5)
cost,dur=research_quote(ag,0,0.0)
assert dur==ag['base_research_time_sec'] and set(cost)=={'food','wood','stone','gold'}
e=Economy({k:999999 for k in ['food','wood','stone','gold']},{k:9999999 for k in ['food','wood','stone','gold']})
q=start_research(e,ag,{},1,3,1000,None,0.0)
assert q and q['target_level']==1
mods=[]; prog={}
assert not complete_research(q,q['finish_timestamp']-1,prog,mods,ag)
assert complete_research(q,q['finish_timestamp'],prog,mods,ag)
assert prog[ag['id']]==1 and mods
# Modifier aggregation is predictable: flat first, then summed percentage.
a=aggregate_modifiers([
 {'stat':'food_production_pct','mode':'PERCENT','value':0.05},
 {'stat':'food_production_pct','mode':'PERCENT','value':0.10},
 {'stat':'training_capacity','mode':'FLAT','value':5},
 {'stat':'training_capacity','mode':'FLAT','value':2},])
assert abs(a['food_production_pct']['percent']-0.15)<1e-9
assert a['training_capacity']['flat']==7
assert apply_modifier(100,a,'food_production_pct')==115
print('PASS dev04 research logic')
