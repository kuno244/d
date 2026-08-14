class_name WorldService
extends RefCounted

var state: Dictionary = {}
var config: Dictionary = {}
var resources: Dictionary = {}
var capacities: Dictionary = {}
var generator := WorldGenerator.new()

func configure(world_state: Dictionary, world_config: Dictionary, resource_state: Dictionary = {}, capacity_state: Dictionary = {}) -> void:
    state = world_state
    config = world_config
    resources = resource_state
    capacities = capacity_state
    generator.configure(config)

func ensure_generated() -> bool:
    if bool(state.get("generated", false)) and not state.get("entities", []).is_empty():
        return false
    var generated := generator.generate(int(state.get("seed", config.get("seed", 731942))))
    for key in generated.keys(): state[key] = generated[key]
    _reveal_cell(_cell_from(state.get("player_city_cell", [512, 512])), 1)
    return true

func process_offline(now: int) -> int:
    var changes := 0
    for entity_variant in state.get("entities", []):
        if not (entity_variant is Dictionary): continue
        var entity: Dictionary = entity_variant
        var respawn := int(entity.get("respawn_timestamp", 0))
        if respawn <= 0 or respawn > now: continue
        if String(entity.get("kind", "")) == "RESOURCE" and bool(entity.get("depleted", false)):
            entity["remaining"] = int(entity.get("total_amount", 0))
            entity["depleted"] = false
            entity["respawn_timestamp"] = 0
            changes += 1
        elif String(entity.get("kind", "")) in ["PVE", "MONSTER_CAMP"] and bool(entity.get("defeated", entity.get("resolved", false))):
            entity["defeated"] = false
            entity["resolved"] = false
            entity["respawn_timestamp"] = 0
            changes += 1
    state["last_world_timestamp"] = now
    return changes

func get_entity(entity_id: String) -> Dictionary:
    for entity_variant in state.get("entities", []):
        if entity_variant is Dictionary and String(entity_variant.get("entity_id", "")) == entity_id:
            return entity_variant
    return {}

func get_army(army_id: String = "army_player_001") -> Dictionary:
    for army_variant in state.get("armies", []):
        if army_variant is Dictionary and String(army_variant.get("army_id", "")) == army_id:
            return army_variant
    return {}

func gather(entity_id: String, requested: int, now: int) -> int:
    var entity := get_entity(entity_id)
    if entity.is_empty() or String(entity.get("kind", "")) != "RESOURCE" or bool(entity.get("depleted", false)) or requested <= 0:
        return 0
    var resource_id := String(entity.get("resource_type", ""))
    var room := maxi(0, int(capacities.get(resource_id, 0)) - int(resources.get(resource_id, 0)))
    var claimed := mini(requested, mini(maxi(0, int(entity.get("remaining", 0))), room))
    if claimed <= 0: return 0
    resources[resource_id] = int(resources.get(resource_id, 0)) + claimed
    entity["remaining"] = int(entity.get("remaining", 0)) - claimed
    if int(entity["remaining"]) <= 0:
        entity["remaining"] = 0
        entity["depleted"] = true
        entity["respawn_timestamp"] = now + int(config.get("resource_respawn_sec", 900))
    _advance_objective(1)
    return claimed

func explore(entity_id: String) -> Dictionary:
    var entity := get_entity(entity_id)
    if entity.is_empty() or String(entity.get("kind", "")) != "RUINS" or bool(entity.get("resolved", false)):
        return {}
    var level := int(entity.get("level", 1))
    var reward := {"food": 80 * level, "wood": 80 * level, "stone": 60 * level, "gold": 35 * level}
    _apply_reward(reward)
    entity["resolved"] = true
    _advance_objective(2)
    return reward

func trade(entity_id: String) -> Dictionary:
    var entity := get_entity(entity_id)
    if entity.is_empty() or String(entity.get("kind", "")) != "VILLAGE": return {}
    var reward := {"food": 120, "wood": 90, "stone": 40, "gold": 30}
    _apply_reward(reward)
    entity["resolved"] = true
    return reward

func prepare_battle(entity_id: String) -> Dictionary:
    var entity := get_entity(entity_id)
    if entity.is_empty() or String(entity.get("kind", "")) not in ["PVE", "MONSTER_CAMP"]: return {}
    if bool(entity.get("defeated", entity.get("resolved", false))): return {}
    var battle := {
        "battle_id": "battle_%s_%d" % [entity_id, int(Time.get_unix_time_from_system())],
        "entity_id": entity_id, "army_id": "army_player_001", "seed": int(state.get("seed", 731942)) + String(entity_id).hash(),
        "enemy_power": int(entity.get("combat_power", 100)), "started_timestamp": int(Time.get_unix_time_from_system())
    }
    state["pending_battle"] = battle
    return battle

func apply_battle_result(result_data: Dictionary, now: int) -> Dictionary:
    var pending = state.get("pending_battle")
    if not (pending is Dictionary): return {}
    var army := get_army(String(pending.get("army_id", "army_player_001")))
    if not army.is_empty() and result_data.get("remaining") is Dictionary:
        army["troops"] = result_data["remaining"].duplicate(true)
        army["status"] = "IDLE"
        army["target_entity_id"] = ""
    var reward: Dictionary = {}
    if bool(result_data.get("victory", false)):
        var entity := get_entity(String(pending.get("entity_id", "")))
        if not entity.is_empty():
            entity["defeated"] = true
            entity["resolved"] = true
            entity["respawn_timestamp"] = now + int(config.get("pve_respawn_sec", 1800))
            reward = entity.get("reward", {}).duplicate(true)
            _apply_reward(reward)
            _advance_objective(3)
    state["pending_battle"] = null
    state["last_world_timestamp"] = now
    return reward

func reveal_around(cell: Vector2i, radius_chunks: int = 1) -> void:
    _reveal_cell(cell, radius_chunks)

func find_world_path(start: Vector2i, target: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
    var width := int(state.get("width", 1024))
    var height := int(state.get("height", 1024))
    if target.x < 0 or target.y < 0 or target.x >= width or target.y >= height or blocked.has(_cell_key(target)): return []
    var frontier: Array[Vector2i] = [start]
    var came_from := {_cell_key(start): start}
    var visited := {_cell_key(start): true}
    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        if current == target: break
        for direction_variant in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
            var direction: Vector2i = direction_variant
            var next: Vector2i = current + direction
            var key: String = _cell_key(next)
            if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height or blocked.has(key) or visited.has(key): continue
            visited[key] = true
            came_from[key] = current
            frontier.append(next)
    if not visited.has(_cell_key(target)): return []
    var path: Array[Vector2i] = []
    var cursor: Vector2i = target
    while cursor != start:
        path.push_front(cursor)
        cursor = came_from[_cell_key(cursor)]
    path.push_front(start)
    return path

func _reveal_cell(cell: Vector2i, radius_chunks: int) -> void:
    var chunk_size := int(state.get("chunk_size", 32))
    var center := Vector2i(cell.x / chunk_size, cell.y / chunk_size)
    var explored: Array = state.get("explored_chunks", [])
    var visible: Array = []
    for y in range(center.y - radius_chunks, center.y + radius_chunks + 1):
        for x in range(center.x - radius_chunks, center.x + radius_chunks + 1):
            if x < 0 or y < 0 or x >= int(state.get("width", 1024)) / chunk_size or y >= int(state.get("height", 1024)) / chunk_size: continue
            var pair := [x, y]
            visible.append(pair)
            if not pair in explored: explored.append(pair)
    state["explored_chunks"] = explored
    state["visible_chunks"] = visible

func _apply_reward(reward: Dictionary) -> void:
    for resource_id in reward.keys():
        resources[resource_id] = mini(int(capacities.get(resource_id, 0)), int(resources.get(resource_id, 0)) + maxi(0, int(reward[resource_id])))

func _advance_objective(target_step: int) -> void:
    var objectives: Dictionary = state.get("objectives", {"chapter": 1, "step": 0})
    objectives["step"] = maxi(int(objectives.get("step", 0)), target_step)
    state["objectives"] = objectives

func _cell_from(value) -> Vector2i:
    if value is Array and value.size() >= 2: return Vector2i(int(value[0]), int(value[1]))
    return Vector2i.ZERO

func _cell_key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x, cell.y]
