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
    var width := int(config.get("width", 1024))
    var height := int(config.get("height", 1024))
    var start_data: Array = config.get("player_start", [512, 512])
    var start := Vector2i(int(start_data[0]), int(start_data[1]))
    _reserve(start)
    var entities: Array = [{
        "entity_id": "city_player_001", "kind": "CITY", "cell": [start.x, start.y],
        "display_name": "Crownkeep", "owner_id": "player", "level": 1
    }]

    var resource_types := ["food", "wood", "stone", "gold"]
    for index in range(int(config.get("resource_nodes", 48))):
        var cell := _free_cell_in_ring(width, height, start, 10.0, 42.0) if index < 20 else _free_cell(width, height, start, 10.0)
        var level := clampi(1 + int(Vector2(cell - start).length() / 105.0), 1, 6)
        var total := 900 * level + rng.randi_range(0, 300)
        entities.append({
            "entity_id": "resource_%03d" % (index + 1), "kind": "RESOURCE", "cell": [cell.x, cell.y],
            "resource_type": resource_types[index % resource_types.size()], "level": level,
            "total_amount": total, "remaining": total, "depleted": false, "respawn_timestamp": 0
        })

    var pve_types := ["monster_forest_troll", "monster_stone_golem", "monster_titan_boar", "monster_armored_wyvern", "monster_cursed_knight"]
    for index in range(int(config.get("pve_encounters", 18))):
        var cell := _free_cell_in_ring(width, height, start, 24.0, 58.0) if index < 10 else _free_cell(width, height, start, 24.0)
        var level := clampi(1 + int(Vector2(cell - start).length() / 55.0), 1, 12)
        entities.append({
            "entity_id": "pve_%03d" % (index + 1), "kind": "PVE", "cell": [cell.x, cell.y],
            "pve_id": pve_types[index % pve_types.size()], "level": level, "combat_power": 95 + level * 55,
            "defeated": false, "respawn_timestamp": 0,
            "reward": {"food": 90 * level, "wood": 70 * level, "stone": 45 * level, "gold": 18 * level}
        })

    _add_neutral_entities(entities, "RUINS", "ruins", width, height, start, 20.0)
    _add_neutral_entities(entities, "VILLAGE", "villages", width, height, start, 14.0)
    _add_neutral_entities(entities, "MONSTER_CAMP", "monster_camps", width, height, start, 34.0)
    _add_neutral_entities(entities, "FORTRESS", "fortresses", width, height, start, 72.0)
    return {
        "seed": seed_value, "generated": true, "width": width, "height": height,
        "chunk_size": int(config.get("chunk_size", 32)), "region_size": int(config.get("region_size", 128)),
        "player_city_id": "city_player_001", "player_city_cell": [start.x, start.y], "entities": entities
    }

func biome_at(cell: Vector2i, seed_value: int) -> String:
    var biomes: Array = config.get("biomes", [])
    if biomes.is_empty(): return "grasslands"
    var scale := maxi(8, int(config.get("biome_scale", 88)))
    var coarse: int = int(cell.x / float(scale)) * 3 + int(cell.y / float(scale)) * 5
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
        var cell := _free_cell_in_ring(width, height, start, minimum_distance, minimum_distance + 46.0) if index < 3 else _free_cell(width, height, start, minimum_distance)
        var level := clampi(1 + int(Vector2(cell - start).length() / 72.0), 1, 10)
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

func _free_cell_in_ring(width: int, height: int, start: Vector2i, minimum_distance: float, maximum_distance: float) -> Vector2i:
    for _attempt in range(2048):
        var cell := Vector2i(
            clampi(start.x + rng.randi_range(-int(maximum_distance), int(maximum_distance)), 2, width - 3),
            clampi(start.y + rng.randi_range(-int(maximum_distance), int(maximum_distance)), 2, height - 3)
        )
        var distance := Vector2(cell - start).length()
        if distance >= minimum_distance and distance <= maximum_distance and not occupied.has(_key(cell)):
            _reserve(cell)
            return cell
    return _free_cell(width, height, start, minimum_distance)

func _reserve(cell: Vector2i) -> void:
    occupied[_key(cell)] = true

func _key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x, cell.y]
