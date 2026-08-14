"""Executable deterministic reference model for DEVELOPMENT 04 logic.

This module mirrors the intended Godot domain-service rules so gameplay math can be
verified while the Godot runtime is unavailable in this workspace. Static data is
read from the same JSON definitions used by the project; no visual/runtime mock data
is introduced here.
"""
from __future__ import annotations
from copy import deepcopy
from dataclasses import dataclass
from math import ceil, floor
from typing import Dict, Iterable, Mapping, MutableMapping, Optional, Tuple

ResourceMap = Dict[str, int]

class CityGrid:
    def __init__(self, width: int, height: int):
        if width <= 0 or height <= 0:
            raise ValueError("grid dimensions must be positive")
        self.width = width
        self.height = height
        self.occupied: Dict[Tuple[int,int], str] = {}
        self.reserved: Dict[Tuple[int,int], str] = {}
        self.records: Dict[str, dict] = {}

    @staticmethod
    def world_to_grid(world_xz, cell_size: float, origin=(0.0,0.0)) -> Tuple[int,int]:
        if cell_size <= 0:
            raise ValueError("cell_size must be positive")
        return (floor((float(world_xz[0])-float(origin[0]))/cell_size),
                floor((float(world_xz[1])-float(origin[1]))/cell_size))

    @staticmethod
    def grid_to_world(grid_xy, cell_size: float, origin=(0.0,0.0)) -> Tuple[float,float]:
        if cell_size <= 0:
            raise ValueError("cell_size must be positive")
        return (float(origin[0]) + (int(grid_xy[0])+0.5)*cell_size,
                float(origin[1]) + (int(grid_xy[1])+0.5)*cell_size)

    @staticmethod
    def footprint_world_center(anchor, footprint, rotation: int, cell_size: float, origin=(0.0,0.0)) -> Tuple[float,float]:
        if cell_size <= 0:
            raise ValueError("cell_size must be positive")
        w,h = CityGrid._rotated_footprint(footprint, rotation)
        base = CityGrid.grid_to_world(anchor, cell_size, origin)
        return (base[0] + (w-1)*cell_size*0.5, base[1] + (h-1)*cell_size*0.5)

    @staticmethod
    def _rotated_footprint(footprint, rotation: int):
        w,h = int(footprint[0]), int(footprint[1])
        r = rotation % 360
        if r not in (0,90,180,270):
            raise ValueError("rotation must be a 90-degree step")
        return (h,w) if r in (90,270) else (w,h)

    def cells(self, anchor, footprint, rotation=0):
        x,y = int(anchor[0]), int(anchor[1])
        w,h = self._rotated_footprint(footprint, rotation)
        return [(x+dx,y+dy) for dy in range(h) for dx in range(w)]

    def can_place(self, anchor, footprint, rotation=0, ignore_instance_id: Optional[str]=None) -> bool:
        for cell in self.cells(anchor, footprint, rotation):
            x,y = cell
            if x < 0 or y < 0 or x >= self.width or y >= self.height:
                return False
            owner = self.occupied.get(cell)
            if owner is not None and owner != ignore_instance_id:
                return False
            reservation = self.reserved.get(cell)
            if reservation is not None and reservation != ignore_instance_id:
                return False
        return True

    def place(self, instance_id: str, anchor, footprint, rotation=0) -> bool:
        if instance_id in self.records or not self.can_place(anchor, footprint, rotation):
            return False
        record={'instance_id':instance_id,'anchor':tuple(anchor),'footprint':tuple(footprint),'rotation':rotation%360}
        self.records[instance_id]=record
        for c in self.cells(anchor, footprint, rotation): self.occupied[c]=instance_id
        return True

    def reserve(self, reservation_id: str, anchor, footprint, rotation=0) -> bool:
        if not self.can_place(anchor, footprint, rotation): return False
        for c in self.cells(anchor, footprint, rotation): self.reserved[c]=reservation_id
        return True

    def release_reservation(self, reservation_id: str) -> None:
        self.reserved={c:v for c,v in self.reserved.items() if v != reservation_id}

    def begin_move(self, instance_id: str):
        record=self.records.get(instance_id)
        if record is None: return None
        token=deepcopy(record)
        self.occupied={c:v for c,v in self.occupied.items() if v != instance_id}
        del self.records[instance_id]
        return token

    def commit_move(self, instance_id: str, anchor, footprint, rotation=0) -> bool:
        return self.place(instance_id, anchor, footprint, rotation)

    def cancel_move(self, token: Optional[dict]) -> bool:
        if not token: return False
        return self.place(token['instance_id'], token['anchor'], token['footprint'], token['rotation'])

    def remove(self, instance_id: str) -> bool:
        if instance_id not in self.records: return False
        self.occupied={c:v for c,v in self.occupied.items() if v != instance_id}
        del self.records[instance_id]
        return True

class Economy:
    def __init__(self, resources: Mapping[str,int], capacities: Mapping[str,int]):
        self.resources={k:max(0,int(v)) for k,v in resources.items()}
        self.capacities={k:max(0,int(v)) for k,v in capacities.items()}
        for k in set(self.resources)|set(self.capacities):
            self.resources.setdefault(k,0); self.capacities.setdefault(k,self.resources[k])
            self.resources[k]=min(self.resources[k],self.capacities[k])

    def add(self, resource_id: str, amount: int) -> int:
        amount=max(0,int(amount)); cur=self.resources.get(resource_id,0); cap=self.capacities.get(resource_id,cur)
        accepted=min(amount,max(0,cap-cur)); self.resources[resource_id]=cur+accepted; return accepted

    def can_afford(self, costs: Mapping[str,int]) -> bool:
        return all(self.resources.get(k,0) >= max(0,int(v)) for k,v in costs.items())

    def spend_atomic(self, costs: Mapping[str,int]) -> bool:
        normalized={k:max(0,int(v)) for k,v in costs.items()}
        if not self.can_afford(normalized): return False
        for k,v in normalized.items(): self.resources[k]=self.resources.get(k,0)-v
        return True

    def set_capacity(self, resource_id: str, capacity: int) -> int:
        self.capacities[resource_id]=max(0,int(capacity))
        overflow=max(0,self.resources.get(resource_id,0)-self.capacities[resource_id])
        self.resources[resource_id]=min(self.resources.get(resource_id,0),self.capacities[resource_id])
        return overflow

def accrue_production(stored: int, last_timestamp: int, now: int, rate_per_hour: float, local_cap: int,
                      offline_cap_sec: int, modifier_pct: float=0.0, max_timestamp_delta_sec: int=604800):
    stored=max(0,int(stored)); local_cap=max(0,int(local_cap)); last_timestamp=int(last_timestamp); now=int(now)
    if now < last_timestamp: return (min(stored,local_cap), last_timestamp)
    elapsed=min(now-last_timestamp,max(0,int(offline_cap_sec)),max(0,int(max_timestamp_delta_sec)))
    rate=max(0.0,float(rate_per_hour))*(1.0+float(modifier_pct))
    produced=max(0,int(floor(rate*elapsed/3600.0)))
    return (min(local_cap,stored+produced), now)

def claim_local(stored: int, economy: Economy, resource_id: str):
    stored=max(0,int(stored)); claimed=economy.add(resource_id,stored); return claimed,stored-claimed

def _level_entry(definition: Mapping, level: int) -> Optional[dict]:
    levels=definition.get('levels',[])
    if level < 1 or level > len(levels): return None
    entry=levels[level-1]
    return entry if int(entry.get('level',-1))==level else next((x for x in levels if int(x.get('level',-1))==level),None)

def can_upgrade(definition: Mapping, current_level: int, citadel_level: int, population: int) -> bool:
    current_level=int(current_level); target=current_level+1
    if current_level < 0 or target > int(definition.get('max_level',0)): return False
    entry=_level_entry(definition,target)
    if entry is None: return False
    if definition.get('id')!='building_royal_citadel' and int(entry.get('citadel_required_level',target)) > int(citadel_level): return False
    if int(entry.get('population_required',0)) > int(population): return False
    return True

def start_construction(economy: Economy, definition: Mapping, instance: MutableMapping, target_level: int, now: int,
                       active_queue: Optional[Mapping], population: int, citadel_level: int, construction_speed_pct: float=0.0):
    if active_queue: return None
    cur=int(instance.get('level',0)); target_level=int(target_level)
    if target_level != cur+1: return None
    if not can_upgrade(definition,cur,int(citadel_level),population): return None
    entry=_level_entry(definition,target_level)
    if entry is None or int(entry.get('population_required',0))>int(population): return None
    costs={k:int(v) for k,v in entry['cost'].items()}
    if not economy.spend_atomic(costs): return None
    duration=max(1,int(ceil(int(entry['build_time_sec'])/max(0.01,1.0+float(construction_speed_pct)))))
    previous_state=str(instance.get('state','ACTIVE')); previous_level=cur
    instance['state']='CONSTRUCTING' if cur==0 else 'UPGRADING'
    return {'type':'BUILD' if cur==0 else 'UPGRADE','building_instance_id':instance.get('instance_id',''),
            'building_id':definition['id'],'previous_state':previous_state,'previous_level':previous_level,
            'target_level':target_level,'start_timestamp':int(now),'finish_timestamp':int(now)+duration,
            'cost_spent':costs,'state':'ACTIVE_QUEUE'}

def complete_construction(instance: MutableMapping, queue: MutableMapping, now: int) -> bool:
    if queue.get('state')!='ACTIVE_QUEUE' or int(now)<int(queue['finish_timestamp']): return False
    instance['level']=int(queue['target_level']); instance['state']='ACTIVE'; queue['state']='COMPLETE'; return True

def cancel_construction(economy: Economy, instance: MutableMapping, queue: MutableMapping, refund_pct: float) -> bool:
    if queue.get('state')!='ACTIVE_QUEUE': return False
    refund_pct=max(0.0,min(1.0,float(refund_pct)))
    for k,v in queue.get('cost_spent',{}).items(): economy.add(k,int(floor(int(v)*refund_pct)))
    instance['level']=int(queue.get('previous_level',instance.get('level',0)))
    instance['state']=queue.get('previous_state','ACTIVE')
    queue['state']='CANCELLED'; return True

def training_quote(troop: Mapping, amount: int, training_speed_pct: float=0.0):
    amount=max(0,int(amount))
    costs={k:int(v)*amount for k,v in troop['base_training_cost'].items()}
    duration=0 if amount==0 else max(1,int(ceil(int(troop['base_training_time_sec'])*amount/max(0.01,1.0+float(training_speed_pct)))))
    return costs,duration

def start_training(economy: Economy, troop: Mapping, amount: int, building_level: int, citadel_level: int,
                   capacity: int, now: int, training_speed_pct: float=0.0, active_queue=None):
    amount=int(amount)
    if active_queue or amount<=0 or amount>int(capacity): return None
    if int(building_level)<int(troop['unlock_building_level']) or int(citadel_level)<int(troop['unlock_citadel_level']): return None
    costs,duration=training_quote(troop,amount,training_speed_pct)
    if not economy.spend_atomic(costs): return None
    return {'troop_id':troop['id'],'amount':amount,'start_timestamp':int(now),'finish_timestamp':int(now)+duration,
            'cost_spent':costs,'state':'TRAINING'}

def complete_training(entry: MutableMapping, now: int, inventory: MutableMapping[str,int]) -> bool:
    if entry.get('state')!='TRAINING' or int(now)<int(entry['finish_timestamp']): return False
    tid=entry['troop_id']; inventory[tid]=int(inventory.get(tid,0))+int(entry['amount']); entry['state']='COMPLETE'; return True

def research_quote(node: Mapping, current_level: int, research_speed_pct: float=0.0):
    current_level=max(0,int(current_level)); mult=float(node.get('cost_growth',1.0))**current_level
    costs={k:int(round(int(v)*mult/5.0)*5) for k,v in node['base_cost'].items()}
    raw=float(node['base_research_time_sec'])*(float(node.get('time_growth',1.0))**current_level)
    duration=max(1,int(ceil(raw/max(0.01,1.0+float(research_speed_pct)))))
    return costs,duration

def can_research(node: Mapping, progress: Mapping[str,int], academy_level: int, citadel_level: int) -> bool:
    cur=int(progress.get(node['id'],0))
    if cur>=int(node['max_level']): return False
    if int(academy_level)<int(node['academy_requirement']): return False
    if int(citadel_level)<int(node.get('citadel_requirement',1)): return False
    return all(int(progress.get(pid,0))>=1 for pid in node.get('prerequisites',[]))

def start_research(economy: Economy, node: Mapping, progress: Mapping[str,int], academy_level: int, citadel_level: int, now: int,
                   active_queue, research_speed_pct: float=0.0):
    if active_queue or not can_research(node,progress,academy_level,citadel_level): return None
    cur=int(progress.get(node['id'],0)); costs,duration=research_quote(node,cur,research_speed_pct)
    if not economy.spend_atomic(costs): return None
    return {'research_id':node['id'],'target_level':cur+1,'start_timestamp':int(now),'finish_timestamp':int(now)+duration,
            'cost_spent':costs,'state':'RESEARCHING'}

def complete_research(queue: MutableMapping, now: int, progress: MutableMapping[str,int], modifiers: list, node: Mapping) -> bool:
    if queue.get('state')!='RESEARCHING' or int(now)<int(queue['finish_timestamp']): return False
    rid=node['id']; progress[rid]=int(queue['target_level'])
    for effect in node.get('effects',[]):
        modifiers.append({'source_type':'research','source_id':rid,'source_level':progress[rid],
                          'stat':effect['stat'],'mode':effect['mode'],'value':float(effect['value_per_level'])})
    queue['state']='COMPLETE'; return True

def aggregate_modifiers(modifiers: Iterable[Mapping]):
    out={}
    for m in modifiers:
        stat=str(m['stat']); bucket=out.setdefault(stat,{'flat':0.0,'percent':0.0})
        mode=str(m.get('mode','FLAT')).upper(); value=float(m.get('value',0.0))
        if mode=='PERCENT': bucket['percent']+=value
        else: bucket['flat']+=value
    return out

def apply_modifier(base: float, aggregated: Mapping, stat: str):
    b=aggregated.get(stat,{'flat':0.0,'percent':0.0})
    value=(float(base)+float(b.get('flat',0.0)))*(1.0+float(b.get('percent',0.0)))
    return int(round(value)) if isinstance(base,int) else value

def calculate_city_power(building_instances, research_progress, troop_inventory, building_defs, research_defs, troop_defs, modifiers):
    building_power=0
    for inst in building_instances:
        if inst.get('state')!='ACTIVE': continue
        d=building_defs.get(inst['building_id']); entry=_level_entry(d,int(inst.get('level',0))) if d else None
        if entry: building_power+=int(entry['power'])
    agg=aggregate_modifiers(modifiers if isinstance(modifiers,list) else [])
    building_power=apply_modifier(building_power,agg,'building_power_pct')
    research_power=sum(int(research_defs[rid]['power_per_level'])*int(level) for rid,level in research_progress.items() if rid in research_defs)
    troop_power=sum(int(troop_defs[tid]['power_per_unit'])*int(count) for tid,count in troop_inventory.items() if tid in troop_defs)
    return int(building_power)+research_power+troop_power

def population_snapshot(building_instances, building_defs, base_current: int, base_cap: int, population_cap_pct: float=0.0):
    contribution=0
    for inst in building_instances:
        if inst.get('state')!='ACTIVE': continue
        d=building_defs.get(inst['building_id']); e=_level_entry(d,int(inst.get('level',0))) if d else None
        if e: contribution+=int(e.get('population_cap_contribution',0))
    cap=max(0,int(round((int(base_cap)+contribution)*(1.0+float(population_cap_pct)))))
    # Population grows with available housing but does not instantly fill all housing.
    current=min(cap,max(0,int(base_current)+int(contribution*0.5)))
    ratio=0.0 if cap<=0 else current/cap
    return {'current':current,'cap':cap,'available':max(0,cap-current),'economy_bonus_pct':0.05 if ratio>=0.75 else 0.0}
