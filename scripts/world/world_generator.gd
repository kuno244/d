class_name WorldGenerator
extends RefCounted

var config: Dictionary = {}
var rng := RandomNumberGenerator.new()
var occupied: Dictionary = {}

func configure(world_config: Dictionary) -> void:
    config = world_config

func generate(seed_value: int) -> Dictionary:
    rng.seed = seed_value
    occupied.clear()
    var width := int(config.get("width", 64))
    var height := int(config.get("height", 64))
    var start_data: Array = config.get("player_start", [32, 32])
    var start := Vector2i(int(start_data[0]), int(start_data[1]))
    _reserve(start)
    var entities: Array = [{
        "entity_id": "city_player_001", "kind": "CITY", "cell": [start.x, start.y],
        "display_name": "Crownkeep", "owner_id": "player", "level": 1
    }]

    var resource_types := ["food", "wood", "stone", "gold"]
    for index in range(int(config.get("resource_nodes", 48))):
        var cell := _free_cell(width, height, start, 4.0)
        var level := clampi(1 + int(Vector2(cell - start).length() / 8.0), 1, 6)
        var total := 900 * level + rng.randi_range(0, 300)
        entities.append({
            "entity_id": "resource_%03d" % (index + 1), "kind": "RESOURCE", "cell": [cell.x, cell.y],
            "resource_type": resource_types[index % resource_types.size()], "level": level,
            "total_amount": total, "remaining": total, "depleted": false, "respawn_timestamp": 0
        })

    var pve_types := ["monster_forest_troll", "monster_stone_golem", "monster_titan_boar", "monster_armored_wyvern", "monster_cursed_knight"]
    for index in range(int(config.get("pve_encounters", 18))):
        var cell := _free_cell(width, height, start, 6.0)
        var level := clampi(1 + int(Vector2(cell - start).length() / 5.0), 1, 12)
        entities.append({
            "entity_id": "pve_%03d" % (index + 1), "kind": "PVE", "cell": [cell.x, cell.y],
            "pve_id": pve_types[index % pve_types.size()], "level": level, "combat_power": 95 + level * 55,
            "defeated": false, "respawn_timestamp": 0,
            "reward": {"food": 90 * level, "wood": 70 * level, "stone": 45 * level, "gold": 18 * level}
        })

    _add_neutral_entities(entities, "RUINS", "ruins", width, height, start, 5.0)
    _add_neutral_entities(entities, "VILLAGE", "villages", width, height, start, 3.0)
    _add_neutral_entities(entities, "MONSTER_CAMP", "monster_camps", width, height, start, 7.0)
    _add_neutral_entities(entities, "FORTRESS", "fortresses", width, height, start, 10.0)
    return {
        "seed": seed_value, "generated": true, "width": width, "height": height,
        "chunk_size": int(config.get("chunk_size", 8)), "region_size": int(config.get("region_size", 16)),
        "player_city_id": "city_player_001", "player_city_cell": [start.x, start.y], "entities": entities
    }

func biome_at(cell: Vector2i, seed_value: int) -> String:
    var biomes: Array = config.get("biomes", [])
    if biomes.is_empty(): return "grasslands"
    var coarse: int = int(cell.x / 10.0) * 3 + int(cell.y / 10.0) * 5
    var detail: int = absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ seed_value)
    var biome_index: int = posmod(coarse + int(detail / 268435456.0), biomes.size())
    return String(biomes[biome_index].get("id", "grasslands"))

func biome_definition(biome_id: String) -> Dictionary:
    for item_variant in config.get("biomes", []):
        var item: Dictionary = item_variant
        if String(item.get("id", "")) == biome_id: return item
    return {}

func _add_neutral_entities(entities: Array, kind: String, config_key: String, width: int, height: int, start: Vector2i, minimum_distance: float) -> void:
    for index in range(int(config.get(config_key, 0))):
        var cell := _free_cell(width, height, start, minimum_distance)
        var level := clampi(1 + int(Vector2(cell - start).length() / 7.0), 1, 10)
        var entity := {
            "entity_id": "%s_%03d" % [kind.to_lower(), index + 1], "kind": kind,
            "cell": [cell.x, cell.y], "level": level, "owner_id": "neutral", "resolved": false
        }
        if kind == "MONSTER_CAMP":
            entity["combat_power"] = 140 + level * 70
            entity["reward"] = {"food": 120 * level, "wood": 100 * level, "stone": 80 * level, "gold": 30 * level}
        entities.append(entity)

func _free_cell(width: int, height: int, start: Vector2i, minimum_distance: float) -> Vector2i:
    for _attempt in range(width * height * 4):
        var cell := Vector2i(rng.randi_range(2, width - 3), rng.randi_range(2, height - 3))
        if not occupied.has(_key(cell)) and Vector2(cell - start).length() >= minimum_distance:
            _reserve(cell)
            return cell
    for y in range(height):
        for x in range(width):
            var fallback := Vector2i(x, y)
            if not occupied.has(_key(fallback)):
                _reserve(fallback)
                return fallback
    return Vector2i.ZERO

func _reserve(cell: Vector2i) -> void:
    occupied[_key(cell)] = true

func _key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x, cell.y]
