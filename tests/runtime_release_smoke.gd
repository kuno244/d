extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    SaveService.delete_save()
    var registry_errors := DataRegistry.initialize()
    _check(registry_errors.is_empty(), "DataRegistry initializes")
    var save_data := SaveService.default_save()
    _check(int(save_data.get("save_version", 0)) == 4, "Save v4 default")
    GameState.reset_from_save(save_data)

    var config: Dictionary = DataRegistry.data.get("world", {}).get("world", {})
    var world_service := WorldService.new()
    world_service.configure(GameState.world_state, config, GameState.resources, GameState.capacities)
    _check(world_service.ensure_generated(), "World generated on first load")
    _check(GameState.world_state.get("entities", []).size() == 1097, "World entity count is 1097")
    _check(not world_service.ensure_generated(), "World generation is idempotent")

    var resource: Dictionary = {}
    var ruins: Dictionary = {}
    var hostile: Dictionary = {}
    for entity_variant in GameState.world_state.get("entities", []):
        var entity: Dictionary = entity_variant
        if resource.is_empty() and String(entity.get("kind", "")) == "RESOURCE": resource = entity
        if ruins.is_empty() and String(entity.get("kind", "")) == "RUINS": ruins = entity
        if hostile.is_empty() and String(entity.get("kind", "")) == "PVE": hostile = entity
    var gathered := world_service.gather(String(resource.get("entity_id", "")), 300, GameClock.unix_time())
    _check(gathered > 0, "World resource gather")
    _check(not world_service.explore(String(ruins.get("entity_id", ""))).is_empty(), "Ruins reward")
    _check(not world_service.prepare_battle(String(hostile.get("entity_id", ""))).is_empty(), "Pending battle created")

    var army := world_service.get_army()
    var troop_power: Dictionary = {}
    for troop_variant in DataRegistry.get_items("troops"):
        var troop: Dictionary = troop_variant
        troop_power[String(troop.get("id", ""))] = int(troop.get("power_per_unit", 1))
    var combat := BattleService.new()
    combat.start(army.get("troops", {}), troop_power, 120, 77)
    for round_index in range(40):
        if bool(combat.snapshot().get("finished", false)): break
        combat.step("COMMANDER_STRIKE" if round_index % 4 == 0 else "STANDARD")
    var result := combat.result()
    _check(bool(result.get("victory", false)), "Deterministic tactical victory")
    _check(not world_service.apply_battle_result(result, GameClock.unix_time()).is_empty(), "Battle reward applied")
    _check(GameState.world_state.get("pending_battle") == null, "Pending battle cleared")
    _check(SaveService.write_current(), "Save v3 writes atomically")

    var world_scene = load("res://scenes/world/WorldMap.tscn").instantiate()
    add_child(world_scene)
    await get_tree().process_frame
    await get_tree().process_frame
    _check(world_scene.active_chunks.size() <= 25 and world_scene.active_chunks.size() > 0, "World chunk budget")
    _check(int(GameState.world_state.get("width", 0)) == 1024 and int(GameState.world_state.get("height", 0)) == 1024, "Large world dimensions")
    _check(world_scene.entity_chunk_index.size() > 100, "World entities indexed by chunk")
    var first_chunk: Node3D = world_scene.active_chunks.values()[0]
    var terrain_mesh: ArrayMesh = first_chunk.get_node("Terrain").mesh
    var mesh_arrays: Array = terrain_mesh.surface_get_arrays(0)
    var terrain_vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
    var first_normal := (terrain_vertices[1] - terrain_vertices[0]).cross(terrain_vertices[2] - terrain_vertices[0]).normalized()
    _check(first_normal.y > 0.5, "Terrain triangles face the camera")
    _check(world_scene.hud.has_node("Safe/Minimap") and world_scene.hud.has_node("Safe/BottomDock"), "Premium world HUD instantiates")
    world_scene.queue_free()
    await get_tree().process_frame

    var battle_scene = load("res://scenes/battle/TacticalBattle.tscn").instantiate()
    add_child(battle_scene)
    await get_tree().process_frame
    _check(battle_scene != null, "Tactical battle scene instantiates")
    battle_scene.queue_free()
    await get_tree().process_frame

    if failures.is_empty():
        print("RELEASE_RUNTIME_SMOKE_PASS")
        get_tree().quit(0)
    else:
        for failure in failures: push_error(failure)
        get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition: failures.append(message)
