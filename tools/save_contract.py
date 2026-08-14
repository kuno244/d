from __future__ import annotations
import json, os, time
from pathlib import Path

CURRENT_SAVE_VERSION = 3
REQUIRED_DICT_KEYS = ("profile","resources","capacities","city_state","progression","troop_state","research_state","world_state")
MAX_TIMER_DELTA_SEC = 90 * 24 * 3600

def default_save(now: int | None = None) -> dict:
    now=int(time.time() if now is None else now)
    return {
        "save_version":CURRENT_SAVE_VERSION,
        "profile":{"created_at":now,"last_played_at":now,"graphics_preset":"medium","camera_sensitivity":1.0,"ui_scale":1.0},
        "resources":{"food":1800,"wood":1800,"stone":900,"gold":450},
        "capacities":{"food":6000,"wood":6000,"stone":4500,"gold":3000},
        "city_state":{
            "buildings":[{"instance_id":"city_citadel_001","building_id":"building_royal_citadel","grid_position":[14,14],"rotation_degrees":0,"level":1,"state":"ACTIVE","production_stored":0,"last_production_timestamp":now}],
            "decorations":[],"construction_queues":[],"construction_queue":None,"production":{},
            "population":{"current":80,"cap":200,"available":120,"economy_bonus_pct":0.0},"city_power":0,
        },
        "progression":{"account_level":1,"account_xp":0,"unlocked_heroes":[],"completed_quests":[],"citadel_level":1},
        "troop_state":{"inventory":{"troop_kingdom_swordsman":45,"troop_kingdom_archer":20},"training_queues":[]},
        "research_state":{"progress":{},"research_queue":None},
        "modifiers":[],
        "world_state":{
            "seed":731942,"generated":False,"width":64,"height":64,"chunk_size":8,"region_size":16,
            "player_city_id":"city_player_001","player_city_cell":[32,32],"entities":[],
            "armies":[{"army_id":"army_player_001","display_name":"Crown Vanguard","cell":[32,34],"troops":{"troop_kingdom_swordsman":50,"troop_kingdom_archer":25},"status":"IDLE","target_entity_id":""}],
            "explored_chunks":[[4,4]],"visible_chunks":[[4,4]],"camera":{"cell":[32,32],"zoom":1.0},
            "pending_battle":None,"last_world_timestamp":now,"objectives":{"chapter":1,"step":0},
            "season_id":"preseason_01",
        },
    }

def _sanitize_queue(q, now: int):
    if not isinstance(q,dict): return None
    start=int(q.get("start_timestamp",now)); finish=int(q.get("finish_timestamp",start))
    start=min(now,max(0,start))
    finish=max(start,min(finish,now+MAX_TIMER_DELTA_SEC))
    q=dict(q); q["start_timestamp"]=start; q["finish_timestamp"]=finish
    return q

def _normalize_v3(result: dict, now: int) -> dict:
    base=default_save(now)
    for key in REQUIRED_DICT_KEYS:
        if not isinstance(result.get(key),dict): result[key]=json.loads(json.dumps(base[key]))
    if not isinstance(result.get("modifiers"),list): result["modifiers"]=[]
    for r in base["resources"]:
        result["capacities"][r]=max(0,int(result["capacities"].get(r,base["capacities"][r])))
        result["resources"][r]=min(result["capacities"][r],max(0,int(result["resources"].get(r,base["resources"][r]))))
    city=result["city_state"]
    if not isinstance(city.get("buildings"),list): city["buildings"]=[]
    if not city["buildings"]: city["buildings"]=json.loads(json.dumps(base["city_state"]["buildings"]))
    if not isinstance(city.get("decorations"),list): city["decorations"]=[]
    if not isinstance(city.get("production"),dict): city["production"]={}
    if not isinstance(city.get("population"),dict): city["population"]=json.loads(json.dumps(base["city_state"]["population"]))
    city["city_power"]=max(0,int(city.get("city_power",0)))
    if not isinstance(city.get("construction_queues"),list):
        city["construction_queues"]=[]
    if not city["construction_queues"] and isinstance(city.get("construction_queue"),dict):
        city["construction_queues"]=[city["construction_queue"]]
    city["construction_queues"]=[_sanitize_queue(q,now) for q in city["construction_queues"] if isinstance(q,dict)]
    city["construction_queue"]=city["construction_queues"][0] if city["construction_queues"] else None
    for b in city["buildings"]:
        if not isinstance(b,dict): continue
        b["level"]=min(20,max(0,int(b.get("level",0))))
        b["rotation_degrees"]=int(b.get("rotation_degrees",0))%360
        gp=b.get("grid_position",[0,0]); b["grid_position"]=[int(gp[0]),int(gp[1])] if isinstance(gp,list) and len(gp)>=2 else [0,0]
        ts=int(b.get("last_production_timestamp",now)); b["last_production_timestamp"]=now if ts<0 or ts>now else ts
        b["production_stored"]=max(0,int(b.get("production_stored",0)))
    troop=result["troop_state"]
    if not isinstance(troop.get("inventory"),dict): troop["inventory"]={}
    troop["inventory"]={str(k):max(0,int(v)) for k,v in troop["inventory"].items()}
    if not isinstance(troop.get("training_queues"),list): troop["training_queues"]=[]
    troop["training_queues"]=[_sanitize_queue(q,now) for q in troop["training_queues"] if isinstance(q,dict)]
    research=result["research_state"]
    if not isinstance(research.get("progress"),dict): research["progress"]={}
    research["progress"]={str(k):max(0,int(v)) for k,v in research["progress"].items()}
    research["research_queue"]=_sanitize_queue(research.get("research_queue"),now)
    result["profile"]["last_played_at"]=now
    world=result["world_state"]
    world_defaults=base["world_state"]
    for key,value in world_defaults.items():
        if key not in world or not isinstance(world[key],type(value)) and value is not None:
            world[key]=json.loads(json.dumps(value))
    world["width"]=64; world["height"]=64; world["chunk_size"]=8; world["region_size"]=16
    camera=world.get("camera",{}) if isinstance(world.get("camera"),dict) else {}
    cell=camera.get("cell",[32,32]); cell=cell if isinstance(cell,list) and len(cell)>=2 else [32,32]
    camera["cell"]=[min(63,max(0,int(cell[0]))),min(63,max(0,int(cell[1])))]
    camera["zoom"]=min(2.2,max(0.35,float(camera.get("zoom",1.0))))
    world["camera"]=camera
    timestamp=int(world.get("last_world_timestamp",now))
    world["last_world_timestamp"]=now if timestamp<0 or timestamp>now else timestamp
    world["entities"]=[entity for entity in world.get("entities",[]) if isinstance(entity,dict)]
    world["armies"]=[army for army in world.get("armies",[]) if isinstance(army,dict)]
    if not world["armies"]: world["armies"]=json.loads(json.dumps(world_defaults["armies"]))
    result["save_version"]=CURRENT_SAVE_VERSION
    return result

def migrate_save(data: dict, now: int | None = None) -> dict:
    now=int(time.time() if now is None else now)
    result=json.loads(json.dumps(data))
    version=int(result.get("save_version",0))
    if version==0:
        result.setdefault("world_state",{"discovered_chunks":[],"armies":[],"pve_states":[],"season_id":"preseason_01"})
        result["save_version"]=1; version=1
    if version==1:
        base=default_save(now)
        old_city=result.get("city_state",{}) if isinstance(result.get("city_state"),dict) else {}
        migrated=base
        for key in ("profile","resources","progression","world_state"):
            if isinstance(result.get(key),dict): migrated[key].update(result[key])
        if isinstance(old_city.get("buildings"),list) and old_city["buildings"]:
            migrated["city_state"]["buildings"]=old_city["buildings"]
        migrated["troop_state"]["training_queues"]=old_city.get("training_queues",[]) if isinstance(old_city.get("training_queues"),list) else []
        rq=old_city.get("research_queue")
        if isinstance(rq,list): rq=rq[0] if rq else None
        migrated["research_state"]["research_queue"]=rq if isinstance(rq,dict) else None
        result=migrated; result["save_version"]=2; version=2
    if version==2:
        old_world=result.get("world_state",{}) if isinstance(result.get("world_state"),dict) else {}
        base_world=default_save(now)["world_state"]
        if isinstance(old_world.get("discovered_chunks"),list):
            base_world["explored_chunks"]=old_world["discovered_chunks"]
        for key,value in old_world.items():
            if key in base_world: base_world[key]=value
        result["world_state"]=base_world
        result["save_version"]=3; version=3
    if version!=CURRENT_SAVE_VERSION: raise ValueError(f"unsupported save version: {version}")
    return _normalize_v3(result,now)

def validate_save(data: dict) -> list[str]:
    errors=[]
    if not isinstance(data,dict): return ["save is not an object"]
    if int(data.get("save_version",-1))!=CURRENT_SAVE_VERSION: errors.append("unsupported save_version")
    for key in REQUIRED_DICT_KEYS:
        if not isinstance(data.get(key),dict): errors.append(f"missing or invalid {key}")
    if not isinstance(data.get("modifiers"),list): errors.append("missing or invalid modifiers")
    city=data.get("city_state",{})
    if isinstance(city,dict):
        if not isinstance(city.get("buildings"),list): errors.append("invalid buildings")
        if not isinstance(city.get("decorations"),list): errors.append("invalid decorations")
    return errors

def atomic_write_json(path: Path | str, data: dict) -> None:
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
    migrated=migrate_save(data)
    errors=validate_save(migrated)
    if errors: raise ValueError(errors)
    temp=Path(str(path)+".tmp"); backup=Path(str(path)+".bak")
    temp.write_text(json.dumps(migrated,separators=(",",":")),encoding="utf-8")
    parsed=json.loads(temp.read_text(encoding="utf-8"))
    if validate_save(parsed): raise ValueError("temporary save validation failed")
    if path.exists():
        if backup.exists(): backup.unlink()
        os.replace(path,backup)
    os.replace(temp,path)

def recover_json(path: Path | str) -> dict:
    path=Path(path); backup=Path(str(path)+".bak")
    for candidate in (path,backup):
        if not candidate.exists(): continue
        try: parsed=migrate_save(json.loads(candidate.read_text(encoding="utf-8")))
        except (json.JSONDecodeError,ValueError,TypeError): continue
        if not validate_save(parsed): return parsed
    return {}
