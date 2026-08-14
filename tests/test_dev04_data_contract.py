import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def load(rel): return json.loads((ROOT/rel).read_text())

buildings=load('data/buildings/buildings.json')['items']
assert len(buildings)==10
expected_ids={
'building_royal_citadel','building_barracks','building_archery_range','building_royal_stable',
'building_grand_academy','building_farm','building_lumber_mill','building_stone_quarry',
'building_watchtower','building_alliance_hall'}
assert {b['id'] for b in buildings}==expected_ids
for b in buildings:
    assert b['max_level']==20, (b['id'],b.get('max_level'))
    assert isinstance(b.get('footprint'), list) and len(b['footprint'])==2 and min(b['footprint'])>0, b['id']
    assert b.get('category') in {'CORE','MILITARY','RESEARCH','ECONOMY','DEFENSE','ALLIANCE'}, b['id']
    assert b.get('functionality'), b['id']
    assert b.get('max_count',0)>=1, b['id']
    levels=b.get('levels')
    assert isinstance(levels,list) and len(levels)==20, (b['id'],len(levels or []))
    assert [x['level'] for x in levels]==list(range(1,21)), b['id']
    for lv in levels:
        assert set(lv['cost'])=={'food','wood','stone','gold'}
        assert all(isinstance(v,int) and v>=0 for v in lv['cost'].values())
        assert lv['build_time_sec']>=0 and lv['power']>0
        assert lv['population_required']>=0
    assert levels[-1]['power']>levels[0]['power']

# Citadel is the central gate and has milestone unlock metadata.
cit=next(x for x in buildings if x['id']=='building_royal_citadel')
assert cit['progression_rule']=='CITY_LEVEL_GATE'
assert len(cit['milestones'])>=8

# Resource producers and storage contributors are explicit.
assert next(x for x in buildings if x['id']=='building_farm')['production']['resource']=='food'
assert next(x for x in buildings if x['id']=='building_lumber_mill')['production']['resource']=='wood'
assert next(x for x in buildings if x['id']=='building_stone_quarry')['production']['resource']=='stone'
assert next(x for x in buildings if x['id']=='building_royal_citadel')['production']['resource']=='gold'
assert all('storage_contribution' in lv for b in buildings for lv in b['levels'])

# Troop unlock progression is data driven and tied to real buildings.
troops=load('data/troops/troops.json')['items']
assert len(troops)==5
for t in troops:
    assert t['training_building_id'] in expected_ids
    assert 1 <= t['unlock_building_level'] <= 20
    assert 1 <= t['unlock_citadel_level'] <= 20
    assert set(t['base_training_cost'])=={'food','wood','stone','gold'}
    assert t['base_training_time_sec']>0 and t['power_per_unit']>0


training_buildings={t['training_building_id'] for t in troops}
for bid in training_buildings:
    b=next(x for x in buildings if x['id']==bid)
    assert all(lv.get('training_capacity',0)>0 for lv in b['levels']), bid

research=load('data/research/research.json')
assert set(research['branches'])=={'economy','military','development','exploration'}
assert len(research['items'])==20
ids={x['id'] for x in research['items']}
for node in research['items']:
    assert node['branch'] in research['branches']
    assert node['max_level']>=1
    assert node['academy_requirement']>=1
    assert node['research_tier'] in range(1,6)
    assert node['citadel_requirement'] in {3,5,7,10,16}
    assert node['effects']
    assert all(p in ids for p in node.get('prerequisites',[]))
    assert node['base_research_time_sec']>0
    assert set(node['base_cost'])=={'food','wood','stone','gold'}
assert any(n.get('prerequisites') for n in research['items'])

city=load('data/city/city_config.json')
assert city['grid']['width']>=20 and city['grid']['height']>=20 and city['grid']['cell_size']>0
assert city['construction']['initial_builder_slots']==1
assert city['offline']['base_cap_sec'] in range(8*3600,13*3600+1)

econ=load('data/economy/economy.json')
assert set(econ['resources'])=={'food','wood','stone','gold'}
assert all(econ['starting_capacity'][r] >= econ['starting_resources'][r] for r in econ['resources'])
print('PASS dev04 data contract')
