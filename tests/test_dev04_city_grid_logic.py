import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'tools'))
from dev04_logic_reference import CityGrid

g=CityGrid(10,10)
assert g.world_to_grid((0.0,0.0), cell_size=2.0, origin=(-10.0,-10.0))==(5,5)
assert g.grid_to_world((5,5), cell_size=2.0, origin=(-10.0,-10.0))==(1.0,1.0)
assert g.footprint_world_center((2,2),(4,4),0,cell_size=2.0,origin=(0.0,0.0))==(8.0,8.0)
assert g.footprint_world_center((0,0),(2,3),90,cell_size=2.0,origin=(0.0,0.0))==(3.0,2.0)
assert g.place('citadel',(2,2),(4,4),0)
assert not g.can_place((3,3),(2,2),0)
assert g.can_place((7,7),(2,2),0)
assert set(g.cells((7,7),(2,3),90))==set(g.cells((7,7),(3,2),0))
# Reservation blocks other objects and can be removed.
assert g.reserve('preview',(0,0),(2,2),0)
assert not g.can_place((0,0),(1,1),0)
g.release_reservation('preview')
assert g.can_place((0,0),(1,1),0)
# Move is transactional: old cells temporarily free, cancel restores exactly.
assert g.place('farm',(7,0),(2,2),0)
token=g.begin_move('farm')
assert token and g.can_place((7,0),(2,2),0)
assert not g.commit_move('farm',(3,3),(2,2),0) # overlaps citadel
assert g.cancel_move(token)
assert not g.can_place((7,0),(2,2),0)
# Valid move leaves one record, no ghost occupancy.
token=g.begin_move('farm'); assert g.commit_move('farm',(7,7),(2,2),0)
assert len([v for v in g.occupied.values() if v=='farm'])==4
assert g.records['farm']['anchor']==(7,7)
print('PASS dev04 city grid logic')
