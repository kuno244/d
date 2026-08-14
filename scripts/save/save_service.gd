extends Node

const CURRENT_SAVE_VERSION := 4
const SAVE_PATH := "user://crownfront_save.json"
const TEMP_PATH := "user://crownfront_save.tmp"
const BACKUP_PATH := "user://crownfront_save.bak"
const MAX_TIMER_DELTA_SEC := 7776000

func default_save() -> Dictionary:
    var now := int(Time.get_unix_time_from_system())
    return {
        "save_version": CURRENT_SAVE_VERSION,
        "profile": {"created_at": now, "last_played_at": now, "graphics_preset": "medium", "camera_sensitivity": 1.0, "ui_scale": 1.0},
        "resources": {"food": 1800, "wood": 1800, "stone": 900, "gold": 450},
        "capacities": {"food": 6000, "wood": 6000, "stone": 4500, "gold": 3000},
        "city_state": {
            "buildings": [{"instance_id": "city_citadel_001", "building_id": "building_royal_citadel", "grid_position": [14, 14], "rotation_degrees": 0, "level": 1, "state": "ACTIVE", "production_stored": 0, "last_production_timestamp": now}],
            "decorations": [], "construction_queues": [], "construction_queue": null, "production": {},
            "population": {"current": 80, "cap": 200, "available": 120, "economy_bonus_pct": 0.0}, "city_power": 0
        },
        "progression": {"account_level": 1, "account_xp": 0, "unlocked_heroes": [], "completed_quests": [], "citadel_level": 1},
        "troop_state": {"inventory": {"troop_kingdom_swordsman": 45, "troop_kingdom_archer": 20}, "training_queues": []},
        "research_state": {"progress": {}, "research_queue": null},
        "modifiers": [],
        "world_state": {
            "seed": 731942, "generated": false, "width": 1024, "height": 1024, "chunk_size": 32, "region_size": 128,
            "player_city_id": "city_player_001", "player_city_cell": [512, 512], "entities": [],
            "armies": [{"army_id": "army_player_001", "display_name": "Crown Vanguard", "cell": [512, 516], "troops": {"troop_kingdom_swordsman": 50, "troop_kingdom_archer": 25}, "status": "IDLE", "target_entity_id": ""}],
            "explored_chunks": [[16, 16]], "visible_chunks": [[16, 16]], "camera": {"cell": [512, 512], "zoom": 2.0},
            "pending_battle": null, "last_world_timestamp": now, "objectives": {"chapter": 1, "step": 0},
            "season_id": "preseason_01"
        }
    }

func load_or_create() -> Dictionary:
    var loaded := _read_valid(SAVE_PATH)
    if loaded.is_empty(): loaded = _read_valid(BACKUP_PATH)
    if loaded.is_empty():
        loaded = default_save()
        write_save(loaded)
    loaded = migrate(loaded)
    EventHub.save_loaded.emit()
    return loaded

func write_current() -> bool:
    var save_data := default_save()
    save_data.merge(GameState.export_state(), true)
    return write_save(save_data)

func write_save(save_data: Dictionary) -> bool:
    var migrated := migrate(save_data.duplicate(true))
    if not validate(migrated).is_empty(): return false
    var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp_file == null: return false
    temp_file.store_string(JSON.stringify(migrated)); temp_file.flush(); temp_file.close()
    if _read_valid(TEMP_PATH).is_empty(): return false
    var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
    var temp_abs := ProjectSettings.globalize_path(TEMP_PATH)
    var backup_abs := ProjectSettings.globalize_path(BACKUP_PATH)
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH): DirAccess.remove_absolute(backup_abs)
        if DirAccess.rename_absolute(save_abs, backup_abs) != OK: return false
    if DirAccess.rename_absolute(temp_abs, save_abs) != OK:
        if FileAccess.file_exists(BACKUP_PATH): DirAccess.rename_absolute(backup_abs, save_abs)
        return false
    EventHub.save_written.emit()
    return true

func migrate(save_data: Dictionary) -> Dictionary:
    var now := int(Time.get_unix_time_from_system())
    var version := int(save_data.get("save_version", 0))
    if version == 0:
        if not save_data.has("world_state"): save_data["world_state"] = {"discovered_chunks": [], "armies": [], "pve_states": [], "season_id": "preseason_01"}
        save_data["save_version"] = 1; version = 1
    if version == 1:
        var base := default_save()
        var old_city: Dictionary = save_data.get("city_state", {}) if save_data.get("city_state") is Dictionary else {}
        for key in ["profile", "resources", "progression", "world_state"]:
            if save_data.get(key) is Dictionary: base[key].merge(save_data[key], true)
        if old_city.get("buildings") is Array and not old_city.get("buildings", []).is_empty(): base["city_state"]["buildings"] = old_city["buildings"]
        if old_city.get("training_queues") is Array: base["troop_state"]["training_queues"] = old_city["training_queues"]
        var old_research = old_city.get("research_queue")
        if old_research is Array: old_research = old_research[0] if not old_research.is_empty() else null
        if old_research is Dictionary: base["research_state"]["research_queue"] = old_research
        save_data = base; save_data["save_version"] = 2; version = 2
    if version == 2:
        var old_world: Dictionary = save_data.get("world_state", {}) if save_data.get("world_state") is Dictionary else {}
        var world_v3: Dictionary = default_save()["world_state"].duplicate(true)
        if old_world.get("discovered_chunks") is Array:
            world_v3["explored_chunks"] = old_world["discovered_chunks"].duplicate(true)
        for key in old_world.keys():
            if world_v3.has(key):
                world_v3[key] = old_world[key]
        save_data["world_state"] = world_v3
        save_data["save_version"] = 3
        version = 3
    if version == 3:
        var old_world: Dictionary = save_data.get("world_state", {}) if save_data.get("world_state") is Dictionary else {}
        var large_world: Dictionary = default_save()["world_state"].duplicate(true)
        for key in ["seed", "objectives", "season_id", "last_world_timestamp"]:
            if old_world.has(key): large_world[key] = old_world[key]
        save_data["world_state"] = large_world
        save_data["save_version"] = 4
        version = 4
    if version != CURRENT_SAVE_VERSION: return save_data
    _normalize_v4(save_data, now)
    return save_data

func validate(save_data: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    if int(save_data.get("save_version", -1)) != CURRENT_SAVE_VERSION: errors.append("Unsupported save_version")
    for key in ["profile", "resources", "capacities", "city_state", "progression", "troop_state", "research_state", "world_state"]:
        if not save_data.has(key) or not (save_data[key] is Dictionary): errors.append("Missing or invalid save key: %s" % key)
    if not (save_data.get("modifiers", []) is Array): errors.append("Missing or invalid modifiers")
    if save_data.get("city_state") is Dictionary:
        if not (save_data["city_state"].get("buildings", []) is Array): errors.append("Invalid buildings")
        if not (save_data["city_state"].get("decorations", []) is Array): errors.append("Invalid decorations")
    return errors

func delete_save() -> void:
    for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func has_save() -> bool:
    return not _read_valid(SAVE_PATH).is_empty() or not _read_valid(BACKUP_PATH).is_empty()

func _normalize_v4(save_data: Dictionary, now: int) -> void:
    var defaults := default_save()
    for key in ["profile", "resources", "capacities", "city_state", "progression", "troop_state", "research_state", "world_state"]:
        if not (save_data.get(key) is Dictionary): save_data[key] = defaults[key].duplicate(true)
    if not (save_data.get("modifiers") is Array): save_data["modifiers"] = []
    for resource_id in defaults["resources"].keys():
        save_data["capacities"][resource_id] = maxi(0, int(save_data["capacities"].get(resource_id, defaults["capacities"][resource_id])))
        save_data["resources"][resource_id] = clampi(int(save_data["resources"].get(resource_id, defaults["resources"][resource_id])), 0, int(save_data["capacities"][resource_id]))
    var city: Dictionary = save_data["city_state"]
    if not (city.get("buildings") is Array): city["buildings"] = []
    if city["buildings"].is_empty(): city["buildings"] = defaults["city_state"]["buildings"].duplicate(true)
    if not (city.get("decorations") is Array): city["decorations"] = []
    if not (city.get("production") is Dictionary): city["production"] = {}
    if not (city.get("population") is Dictionary): city["population"] = defaults["city_state"]["population"].duplicate(true)
    city["city_power"] = maxi(0, int(city.get("city_power", 0)))
    if not (city.get("construction_queues") is Array): city["construction_queues"] = []
    if city["construction_queues"].is_empty() and city.get("construction_queue") is Dictionary: city["construction_queues"].append(city["construction_queue"])
    var sanitized_construction_queues: Array = []
    for queue_variant in city["construction_queues"]:
        var sanitized = _sanitize_queue(queue_variant, now)
        if sanitized is Dictionary:
            sanitized_construction_queues.append(sanitized)
    city["construction_queues"] = sanitized_construction_queues
    city["construction_queue"] = city["construction_queues"][0] if not city["construction_queues"].is_empty() else null
    for instance_variant in city["buildings"]:
        if not (instance_variant is Dictionary): continue
        var instance: Dictionary = instance_variant
        instance["level"] = clampi(int(instance.get("level", 0)), 0, 20)
        instance["rotation_degrees"] = posmod(int(instance.get("rotation_degrees", 0)), 360)
        var gp: Array = instance.get("grid_position", [0, 0])
        instance["grid_position"] = [int(gp[0]), int(gp[1])] if gp.size() >= 2 else [0, 0]
        var ts := int(instance.get("last_production_timestamp", now))
        instance["last_production_timestamp"] = now if ts < 0 or ts > now else ts
        instance["production_stored"] = maxi(0, int(instance.get("production_stored", 0)))
    var troop: Dictionary = save_data["troop_state"]
    if not (troop.get("inventory") is Dictionary):
        troop["inventory"] = {}
    for troop_id in troop["inventory"].keys():
        troop["inventory"][troop_id] = maxi(0, int(troop["inventory"][troop_id]))
    if not (troop.get("training_queues") is Array):
        troop["training_queues"] = []
    var sanitized_training_queues: Array = []
    for queue_variant in troop["training_queues"]:
        var sanitized = _sanitize_queue(queue_variant, now)
        if sanitized is Dictionary:
            sanitized_training_queues.append(sanitized)
    troop["training_queues"] = sanitized_training_queues
    var research: Dictionary = save_data["research_state"]
    if not (research.get("progress") is Dictionary):
        research["progress"] = {}
    for research_id in research["progress"].keys():
        research["progress"][research_id] = maxi(0, int(research["progress"][research_id]))
    research["research_queue"] = _sanitize_queue(research.get("research_queue"), now)
    var world: Dictionary = save_data["world_state"]
    var world_defaults: Dictionary = defaults["world_state"]
    for key in world_defaults.keys():
        if not world.has(key) or (world_defaults[key] != null and typeof(world[key]) != typeof(world_defaults[key])):
            world[key] = world_defaults[key].duplicate(true) if world_defaults[key] is Array or world_defaults[key] is Dictionary else world_defaults[key]
    var incompatible_world := int(world.get("width", 0)) != 1024 or int(world.get("height", 0)) != 1024 or int(world.get("chunk_size", 0)) != 32
    if incompatible_world:
        world["generated"] = false
        world["entities"] = []
        world["armies"] = world_defaults["armies"].duplicate(true)
        world["explored_chunks"] = world_defaults["explored_chunks"].duplicate(true)
        world["visible_chunks"] = world_defaults["visible_chunks"].duplicate(true)
    world["width"] = 1024
    world["height"] = 1024
    world["chunk_size"] = 32
    world["region_size"] = 128
    world["player_city_cell"] = [512, 512]
    var camera: Dictionary = world.get("camera", {}) if world.get("camera") is Dictionary else {}
    var camera_cell: Array = camera.get("cell", [512, 512])
    camera["cell"] = [clampi(int(camera_cell[0]), 0, 1023), clampi(int(camera_cell[1]), 0, 1023)] if camera_cell.size() >= 2 else [512, 512]
    camera["zoom"] = clampf(float(camera.get("zoom", 2.0)), 0.28, 3.6)
    world["camera"] = camera
    var world_timestamp := int(world.get("last_world_timestamp", now))
    world["last_world_timestamp"] = now if world_timestamp < 0 or world_timestamp > now else world_timestamp
    if not (world.get("entities") is Array):
        world["entities"] = []
    else:
        var sanitized_entities: Array = []
        for entity in world["entities"]:
            if entity is Dictionary:
                sanitized_entities.append(entity)
        world["entities"] = sanitized_entities
    if not (world.get("armies") is Array): world["armies"] = []
    if world["armies"].is_empty(): world["armies"] = world_defaults["armies"].duplicate(true)
    save_data["profile"]["last_played_at"] = now
    save_data["save_version"] = CURRENT_SAVE_VERSION

func _sanitize_queue(queue_variant, now: int):
    if not (queue_variant is Dictionary): return null
    var queue: Dictionary = queue_variant.duplicate(true)
    var start := clampi(int(queue.get("start_timestamp", now)), 0, now)
    var finish := clampi(int(queue.get("finish_timestamp", start)), start, now + MAX_TIMER_DELTA_SEC)
    queue["start_timestamp"] = start; queue["finish_timestamp"] = finish
    return queue

func _read_valid(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary): return {}
    var migrated := migrate(parsed)
    if not validate(migrated).is_empty(): return {}
    return migrated
