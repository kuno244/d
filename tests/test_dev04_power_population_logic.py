import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from dev04_logic_reference import calculate_city_power, population_snapshot
buildings={x['id']:x for x in json.loads((ROOT/'data/buildings/buildings.json').read_text())['items']}
troops={x['id']:x for x in json.loads((ROOT/'data/troops/troops.json').read_text())['items']}
research={x['id']:x for x in json.loads((ROOT/'data/research/research.json').read_text())['items']}
instances=[{'building_id':'building_royal_citadel','level':2,'state':'ACTIVE'},{'building_id':'building_farm','level':3,'state':'ACTIVE'}]
prog={'research_agricultural_methods':2}; inv={'troop_kingdom_swordsman':10}
p1=calculate_city_power(instances,prog,inv,buildings,research,troops,{})
p2=calculate_city_power(instances,prog,inv,buildings,research,troops,{})
assert p1==p2 and p1>0
pop=population_snapshot(instances,buildings,80,200,0.0)
assert pop['cap']>200 and 0<=pop['current']<=pop['cap']
assert 0.0 <= pop['economy_bonus_pct'] <= 0.05
print('PASS dev04 power population logic')
