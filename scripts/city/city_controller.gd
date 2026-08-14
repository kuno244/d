extends Node3D

const BuildingRuntimeScene = preload("res://scenes/city/BuildingRuntime.tscn")

@export var selection_mask: int = 1
@onready var camera_root: StrategyCamera = $CameraRoot
@onready var camera: Camera3D = $CameraRoot/Camera3D
@onready var building_root: Node3D = $BuildingRoot
@onready var decoration_root: Node3D = $DecorationRoot
@onready var placement_root: Node3D = $PlacementRoot
@onready var build_mode: BuildModeController = $BuildModeController
@onready var hud: CityHUD = $UIRoot/CityHUD

var grid := CityGridService.new()
var economy := EconomyService.new()
var modifiers := ModifierService.new()
var production := ProductionService.new()
var population := PopulationService.new()
var construction := ConstructionService.new()
var inventory := TroopInventory.new()
var training := TrainingService.new()
var research := ResearchService.new()
var city_power := CityPowerService.new()

var building_definitions: Dictionary = {}
var troop_definitions: Dictionary = {}
var research_definitions: Dictionary = {}
var building_views: Dictionary = {}
var decoration_views: Dictionary = {}
var selected_view: CityBuildingView
var _instance_sequence := 0
var _tick_accumulator := 0.0
var _lod_accumulator := 0.0

func _ready() -> void:
    if not DataRegistry.initialized:
        var errors := DataRegistry.initialize()
        if not errors.is_empty():
            push_error("City cannot initialize DataRegistry: %s" % errors)
            return
    _build_definition_maps()
    _configure_services()
    _rebuild_grid_and_visuals()
    _process_offline_progress(GameClock.unix_time())
    refresh_derived_state()
    hud.bind_city(self)
    if not build_mode.mode_changed.is_connected(hud.refresh_placement_mode):
        build_mode.mode_changed.connect(hud.refresh_placement_mode)
    if not build_mode.placement_feedback.is_connected(hud.set_placement_validity):
        build_mode.placement_feedback.connect(hud.set_placement_validity)
    hud.refresh_placement_mode(build_mode.mode)
    EventHub.city_loaded.emit()

func _process(delta: float) -> void:
    _tick_accumulator += delta
    _lod_accumulator += delta
    if _tick_accumulator >= 1.0:
        _tick_accumulator = 0.0
        var changed := _process_due_timers(GameClock.unix_time())
        if changed:
            refresh_derived_state()
            SaveService.write_current()
        hud.refresh_all()
    if _lod_accumulator >= 0.35:
        _lod_accumulator = 0.0
        _update_lods()


func _exit_tree() -> void:
    if not GameState.city_state.is_empty():
        SaveService.write_current()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        if not GameState.city_state.is_empty():
            SaveService.write_current()

func _configure_services() -> void:
    var city_config: Dictionary = DataRegistry.data.get("city", {})
    grid.configure(city_config.get("grid", {}))
    economy.configure(GameState.resources, GameState.capacities)
    modifiers.configure(GameState.modifiers)
    population.configure(GameState.city_state.get("population", {}), modifiers, DataRegistry.data.get("progression", {}))
    production.configure(economy, modifiers, city_config)
    construction.configure(economy, modifiers, GameState.city_state, city_config)
    inventory.configure(GameState.troop_state.get("inventory", {}))
    training.configure(economy, modifiers, population, inventory, GameState.troop_state)
    research.configure(economy, modifiers, GameState.research_state)
    build_mode.configure(self, grid, construction)

func _build_definition_maps() -> void:
    building_definitions.clear(); troop_definitions.clear(); research_definitions.clear()
    for item_variant in DataRegistry.get_items("buildings"):
        var item: Dictionary = item_variant; building_definitions[String(item.get("id", ""))] = item
    for item_variant in DataRegistry.get_items("troops"):
        var item: Dictionary = item_variant; troop_definitions[String(item.get("id", ""))] = item
    for item_variant in DataRegistry.get_items("research"):
        var item: Dictionary = item_variant; research_definitions[String(item.get("id", ""))] = item

func _rebuild_grid_and_visuals() -> void:
    for child in building_root.get_children(): child.queue_free()
    for child in decoration_root.get_children(): child.queue_free()
    building_views.clear(); decoration_views.clear()
    grid.occupied.clear(); grid.reservations.clear(); grid.records.clear()
    for instance_variant in GameState.city_state.get("buildings", []):
        if not (instance_variant is Dictionary): continue
        var instance: Dictionary = instance_variant
        var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
        if definition.is_empty():
            instance["state"] = "DISABLED"
            continue
        var gp: Array = instance.get("grid_position", [0, 0])
        var anchor := Vector2i(int(gp[0]), int(gp[1]))
        var footprint := _footprint(definition)
        if not grid.occupy(String(instance.get("instance_id", "")), anchor, footprint, int(instance.get("rotation_degrees", 0))):
            instance["state"] = "DISABLED"
            continue
        spawn_building_view(instance)
    for decoration_variant in GameState.city_state.get("decorations", []):
        if decoration_variant is Dictionary:
            _spawn_decoration_from_state(decoration_variant)

func _process_offline_progress(now: int) -> void:
    var instances := _instances_by_id()
    var queue_before = GameState.city_state.get("construction_queue")
    var construction_finish := int(queue_before.get("finish_timestamp", now)) if queue_before is Dictionary else now
    if construction.complete_if_due(instances, now):
        var completed_id := String(queue_before.get("building_instance_id", "")) if queue_before is Dictionary else ""
        if instances.has(completed_id):
            var completed: Dictionary = instances[completed_id]
            completed["last_production_timestamp"] = mini(now, maxi(int(completed.get("last_production_timestamp", construction_finish)), construction_finish))
            _sync_building_view(completed_id)
    training.complete_due(now)
    research.complete_if_due(research_definitions, now)
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
        if not definition.is_empty(): production.accrue(instance, definition, now)
    SaveService.write_current()

func _process_due_timers(now: int) -> bool:
    var changed := false
    var queue_before = GameState.city_state.get("construction_queue")
    var instances := _instances_by_id()
    if construction.complete_if_due(instances, now):
        changed = true
        var completed_id := String(queue_before.get("building_instance_id", "")) if queue_before is Dictionary else ""
        if instances.has(completed_id):
            var completed: Dictionary = instances[completed_id]
            var finish_ts := int(queue_before.get("finish_timestamp", now)) if queue_before is Dictionary else now
            completed["last_production_timestamp"] = finish_ts
            _sync_building_view(completed_id)
    if training.complete_due(now) > 0: changed = true
    if research.complete_if_due(research_definitions, now): changed = true
    return changed

func refresh_derived_state() -> void:
    var base_capacity: Dictionary = DataRegistry.data.get("economy", {}).get("starting_capacity", {})
    var storage_bonus := 0
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        if String(instance.get("state", "")) != "ACTIVE": continue
        var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
        var level := int(instance.get("level", 0))
        if level >= 1 and level <= definition.get("levels", []).size(): storage_bonus += int(definition["levels"][level - 1].get("storage_contribution", 0))
    for resource_id in ["food", "wood", "stone", "gold"]:
        economy.set_capacity(resource_id, roundi(modifiers.apply(int(base_capacity.get(resource_id, 0)) + storage_bonus, "resource_capacity_pct")))
    var pop := population.recalculate(GameState.city_state.get("buildings", []), building_definitions)
    var economy_bonus := float(pop.get("economy_bonus_pct", 0.0))
    for resource_id in ["food", "wood", "stone"]:
        modifiers.set_modifier("population", "city_population", "%s_production_pct" % resource_id, "PERCENT", economy_bonus)
    GameState.city_state["city_power"] = city_power.calculate(GameState.city_state.get("buildings", []), GameState.research_state.get("progress", {}), GameState.troop_state.get("inventory", {}), building_definitions, research_definitions, troop_definitions, modifiers)
    GameState.progression["citadel_level"] = get_citadel_level()
    if hud != null: hud.refresh_all()

func request_build(building_id: String) -> bool:
    return build_mode.begin_build(building_id)

func request_decoration(asset_id: String) -> bool:
    return build_mode.begin_decoration(asset_id)

func request_upgrade(instance_id: String) -> bool:
    var instance := get_building_state(instance_id)
    if instance.is_empty(): return false
    var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
    var now := GameClock.unix_time()
    if definition.has("production"):
        production.accrue(instance, definition, now)
    var ok := construction.start_upgrade(definition, instance, now, get_citadel_level(), get_population_current(), get_active_building_levels())
    if ok:
        _sync_building_view(instance_id); refresh_derived_state(); SaveService.write_current(); hud.show_building(get_building_view_model(instance_id))
    return ok

func request_move(instance_id: String) -> bool:
    return build_mode.begin_move(instance_id)

func request_collect(instance_id: String) -> int:
    var instance := get_building_state(instance_id)
    if instance.is_empty(): return 0
    var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
    if not definition.has("production"): return 0
    var amount := production.claim(instance, definition, GameClock.unix_time())
    if amount > 0: SaveService.write_current(); hud.refresh_all()
    return amount

func request_train(troop_id: String, amount: int) -> bool:
    var troop: Dictionary = troop_definitions.get(troop_id, {})
    if troop.is_empty(): return false
    var candidates: Array = []
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        if String(instance.get("building_id", "")) == String(troop.get("training_building_id", "")) and String(instance.get("state", "")) == "ACTIVE": candidates.append(instance)
    candidates.sort_custom(func(a, b): return int(a.get("level", 0)) > int(b.get("level", 0)))
    if candidates.is_empty(): return false
    var instance: Dictionary = candidates[0]
    var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
    var ok := training.start_training(troop, instance, definition, amount, get_citadel_level(), GameClock.unix_time())
    if ok: SaveService.write_current(); hud.refresh_all()
    return ok

func get_training_status(troop_id: String, amount: int) -> Dictionary:
    var troop: Dictionary = troop_definitions.get(troop_id, {})
    if troop.is_empty(): return {"available": false}
    var best: Dictionary = {}
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        if String(instance.get("building_id", "")) == String(troop.get("training_building_id", "")) and String(instance.get("state", "")) == "ACTIVE":
            if best.is_empty() or int(instance.get("level", 0)) > int(best.get("level", 0)): best = instance
    if best.is_empty(): return {"available": false}
    var definition: Dictionary = building_definitions.get(String(best.get("building_id", "")), {})
    var level := int(best.get("level", 0)); var level_data: Dictionary = definition.get("levels", [])[level - 1]
    var cap := population.training_capacity_for(int(level_data.get("training_capacity", 0)), int(troop.get("population_per_unit", 1)))
    var offer := training.quote(troop, amount, level_data)
    var unlocked := level >= int(troop.get("unlock_building_level", 1)) and get_citadel_level() >= int(troop.get("unlock_citadel_level", 1))
    var no_queue := true
    for q_variant in GameState.troop_state.get("training_queues", []):
        var q: Dictionary = q_variant
        if String(q.get("building_instance_id", "")) == String(best.get("instance_id", "")) and String(q.get("state", "")) == "TRAINING": no_queue = false
    return {"available": unlocked and no_queue and amount > 0 and amount <= cap and economy.can_afford(offer.get("cost", {})), "capacity": cap, "cost": offer.get("cost", {}), "duration_sec": int(offer.get("duration_sec", 0))}

func get_research_status(research_id: String) -> Dictionary:
    var definition: Dictionary = research_definitions.get(research_id, {})
    if definition.is_empty(): return {"available": false}
    var academy_level := _highest_active_building_level("building_grand_academy")
    var offer := research.quote(definition)
    return {"available": research.can_start(definition, academy_level, get_citadel_level()) and economy.can_afford(offer.get("cost", {})), "cost": offer.get("cost", {}), "duration_sec": int(offer.get("duration_sec", 0)), "academy_level": academy_level}

func request_research(research_id: String) -> bool:
    var definition: Dictionary = research_definitions.get(research_id, {})
    if definition.is_empty(): return false
    var academy_level := _highest_active_building_level("building_grand_academy")
    var ok := research.start_research(definition, academy_level, get_citadel_level(), GameClock.unix_time())
    if ok: SaveService.write_current(); hud.refresh_all()
    return ok

func request_cancel_construction() -> bool:
    var now := GameClock.unix_time()
    var result := construction.cancel(_instances_by_id(), now)
    if result.is_empty(): return false
    var instance_id := String(result.get("building_instance_id", ""))
    if bool(result.get("remove_instance", false)):
        grid.release(instance_id); remove_building_state(instance_id)
    else:
        _sync_building_view(instance_id)
    refresh_derived_state(); SaveService.write_current(); return true

func request_construction_speedup(seconds: int) -> int:
    var reduced := construction.speed_up(seconds, GameClock.unix_time())
    if reduced > 0: SaveService.write_current(); hud.refresh_all()
    return reduced

func create_building_state(building_id: String, anchor: Vector2i, rotation: int) -> Dictionary:
    if not building_definitions.has(building_id): return {}
    _instance_sequence += 1
    var now := GameClock.unix_time()
    return {"instance_id": "%s_%d_%d" % [building_id, now, _instance_sequence], "building_id": building_id, "grid_position": [anchor.x, anchor.y], "rotation_degrees": posmod(rotation, 360), "level": 0, "state": "PLACING", "production_stored": 0, "last_production_timestamp": now}

func add_building_state(instance: Dictionary) -> void:
    GameState.city_state.get("buildings", []).append(instance)

func remove_building_state(instance_id: String) -> bool:
    var buildings: Array = GameState.city_state.get("buildings", [])
    for index in range(buildings.size() - 1, -1, -1):
        if String(buildings[index].get("instance_id", "")) == instance_id:
            buildings.remove_at(index)
            if building_views.has(instance_id):
                building_views[instance_id].queue_free(); building_views.erase(instance_id)
            return true
    return false

func get_building_state(instance_id: String) -> Dictionary:
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        if String(instance.get("instance_id", "")) == instance_id: return instance
    return {}

func get_building_view(instance_id: String) -> CityBuildingView:
    return building_views.get(instance_id) as CityBuildingView

func spawn_building_view(instance: Dictionary) -> CityBuildingView:
    var building_id := String(instance.get("building_id", ""))
    if not DataRegistry.asset_service.is_shipping_ready(building_id): return null
    var view := BuildingRuntimeScene.instantiate() as CityBuildingView
    building_root.add_child(view)
    view.configure(instance, building_definitions[building_id], DataRegistry.asset_service, grid, DataRegistry.data.get("city", {}).get("lod_profiles", {}))
    building_views[String(instance.get("instance_id", ""))] = view
    return view

func create_preview_view(building_id: String, anchor: Vector2i, rotation: int) -> CityBuildingView:
    if not DataRegistry.asset_service.is_shipping_ready(building_id): return null
    var preview_state := {"instance_id": "placement_preview", "building_id": building_id, "grid_position": [anchor.x, anchor.y], "rotation_degrees": rotation, "level": 1, "state": "PLACING"}
    var view := BuildingRuntimeScene.instantiate() as CityBuildingView
    placement_root.add_child(view); view.collision_layer = 0; view.collision_mask = 0
    view.configure(preview_state, building_definitions[building_id], DataRegistry.asset_service, grid, DataRegistry.data.get("city", {}).get("lod_profiles", {}))
    return view

func update_preview_transform(view: CityBuildingView, anchor: Vector2i, rotation: int) -> void:
    if view == null:
        return
    view.set_grid_transform(anchor, rotation)

func update_building_position(instance_id: String, anchor: Vector2i, rotation: int) -> void:
    var instance := get_building_state(instance_id)
    if instance.is_empty(): return
    instance["grid_position"] = [anchor.x, anchor.y]; instance["rotation_degrees"] = posmod(rotation, 360)
    _sync_building_view(instance_id)

func get_upgrade_status(instance_id: String) -> Dictionary:
    var instance := get_building_state(instance_id)
    if instance.is_empty():
        return {"available": false, "reason": "MISSING_BUILDING", "requirements": []}
    var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
    if definition.is_empty():
        return {"available": false, "reason": "MISSING_DEFINITION", "requirements": []}
    var level := int(instance.get("level", 0))
    var max_level := int(definition.get("max_level", 20))
    if level >= max_level:
        return {"available": false, "reason": "MAX_LEVEL", "requirements": [], "cost": {}, "duration_sec": 0}
    var target_level := level + 1
    var levels: Array = definition.get("levels", [])
    if target_level < 1 or target_level > levels.size():
        return {"available": false, "reason": "INVALID_LEVEL_DATA", "requirements": []}
    var target_data: Dictionary = levels[target_level - 1]
    var requirements: Array = []
    var citadel_level := get_citadel_level()
    var required_citadel := int(target_data.get("citadel_required_level", target_level))
    if String(definition.get("id", "")) != "building_royal_citadel":
        requirements.append("Citadel Lv.%d" % required_citadel)
    for requirement_variant in definition.get("prerequisites", []):
        var requirement: Dictionary = requirement_variant
        requirements.append("%s Lv.%d" % [String(requirement.get("building_id", "")), int(requirement.get("level", 1))])
    var population_required := int(target_data.get("population_required", 0))
    if population_required > 0:
        requirements.append("Population %d" % population_required)
    var rules_ok := construction.can_upgrade(definition, instance, citadel_level, get_population_current(), get_active_building_levels())
    var cost: Dictionary = target_data.get("cost", {}).duplicate(true)
    var affordable := economy.can_afford(cost)
    var speed := modifiers.percent("construction_speed_pct")
    var duration := maxi(1, ceili(float(target_data.get("build_time_sec", 1)) / maxf(0.01, 1.0 + speed)))
    var reason := "READY"
    if String(instance.get("state", "")) != "ACTIVE":
        reason = "BUILDING_%s" % String(instance.get("state", "UNKNOWN"))
    elif construction.queue_slots_full():
        reason = "CONSTRUCTION_QUEUE_BUSY"
    elif String(definition.get("id", "")) != "building_royal_citadel" and required_citadel > citadel_level:
        reason = "REQUIRES_CITADEL_%d" % required_citadel
    elif population_required > get_population_current():
        reason = "REQUIRES_POPULATION_%d" % population_required
    elif not construction.prerequisites_met(definition, get_active_building_levels(), citadel_level):
        reason = "PREREQUISITE_NOT_MET"
    elif not affordable:
        reason = "INSUFFICIENT_RESOURCES"
    elif not rules_ok:
        reason = "PROGRESSION_LOCKED"
    return {
        "available": rules_ok and affordable,
        "reason": reason,
        "requirements": requirements,
        "cost": cost,
        "duration_sec": duration,
        "target_level": target_level
    }

func get_building_view_model(instance_id: String) -> Dictionary:
    var instance := get_building_state(instance_id)
    if instance.is_empty(): return {}
    var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
    var view_model := BuildingInfoViewModel.from_state(instance, definition, construction.get_queue())
    var upgrade_status := get_upgrade_status(instance_id)
    view_model["upgrade_available"] = bool(upgrade_status.get("available", false))
    view_model["upgrade_status"] = String(upgrade_status.get("reason", ""))
    view_model["requirements"] = upgrade_status.get("requirements", []).duplicate(true)
    if upgrade_status.has("cost"):
        view_model["upgrade_cost"] = upgrade_status.get("cost", {}).duplicate(true)
    if upgrade_status.has("duration_sec"):
        view_model["upgrade_duration_sec"] = int(upgrade_status.get("duration_sec", 0))
    view_model["can_move"] = String(instance.get("state", "")) == "ACTIVE"
    view_model["can_collect"] = definition.has("production") and String(instance.get("state", "")) == "ACTIVE"
    return view_model

func add_decoration_state(asset_id: String, anchor: Vector2i, rotation: int) -> bool:
    var decoration_id := "decoration_%d_%d" % [GameClock.unix_time(), _instance_sequence]
    _instance_sequence += 1
    if not grid.occupy(decoration_id, anchor, Vector2i.ONE, rotation): return false
    var state := {"instance_id": decoration_id, "asset_id": asset_id, "grid_position": [anchor.x, anchor.y], "rotation_degrees": posmod(rotation, 360)}
    GameState.city_state.get("decorations", []).append(state); _spawn_decoration_from_state(state); SaveService.write_current(); return true

func request_move_decoration(decoration_id: String) -> bool:
    return build_mode.begin_move_decoration(decoration_id)

func request_remove_decoration(decoration_id: String) -> bool:
    return remove_decoration(decoration_id)

func get_decoration_state(decoration_id: String) -> Dictionary:
    for state_variant in GameState.city_state.get("decorations", []):
        if state_variant is Dictionary and String(state_variant.get("instance_id", "")) == decoration_id:
            return state_variant
    return {}

func get_decoration_view(decoration_id: String) -> Node3D:
    return decoration_views.get(decoration_id) as Node3D

func create_decoration_preview(asset_id: String, anchor: Vector2i, rotation: int) -> Node3D:
    var path := DataRegistry.asset_service.get_lod(asset_id, 0)
    if path.is_empty():
        return null
    var packed = load("res://%s" % path)
    if not (packed is PackedScene):
        return null
    var wrapper := Node3D.new()
    wrapper.name = "DecorationPreview"
    wrapper.global_position = grid.grid_to_world(anchor)
    wrapper.rotation_degrees.y = float(rotation)
    var visual := packed.instantiate() as Node3D
    visual.scale = Vector3.ONE * 1.8
    wrapper.add_child(visual)
    var marker := MeshInstance3D.new()
    marker.name = "PlacementMarker"
    var marker_mesh := BoxMesh.new()
    marker_mesh.size = Vector3(grid.cell_size, 0.08, grid.cell_size)
    marker.mesh = marker_mesh
    marker.position.y = 0.04
    var marker_material := StandardMaterial3D.new()
    marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_material.albedo_color = Color(0.18, 0.9, 0.35, 0.42)
    marker.material_override = marker_material
    wrapper.add_child(marker)
    placement_root.add_child(wrapper)
    return wrapper

func set_decoration_placement_feedback(view: Node3D, valid: bool) -> void:
    if view == null:
        return
    var marker := view.get_node_or_null("PlacementMarker") as MeshInstance3D
    if marker == null:
        marker = MeshInstance3D.new()
        marker.name = "PlacementMarker"
        var marker_mesh := BoxMesh.new()
        marker_mesh.size = Vector3(grid.cell_size, 0.08, grid.cell_size)
        marker.mesh = marker_mesh
        marker.position.y = 0.04
        view.add_child(marker)
    var material := marker.material_override as StandardMaterial3D
    if material == null:
        material = StandardMaterial3D.new()
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        marker.material_override = material
    material.albedo_color = Color(0.18, 0.9, 0.35, 0.42) if valid else Color(0.95, 0.2, 0.18, 0.46)
    marker.visible = true

func clear_decoration_placement_feedback(view: Node3D) -> void:
    if view == null:
        return
    var marker := view.get_node_or_null("PlacementMarker")
    if marker != null:
        marker.queue_free()

func update_decoration_preview_transform(view: Node3D, anchor: Vector2i, rotation: int) -> void:
    if view == null:
        return
    view.global_position = grid.grid_to_world(anchor)
    view.rotation_degrees.y = float(rotation)

func update_decoration_position(decoration_id: String, anchor: Vector2i, rotation: int) -> void:
    var state := get_decoration_state(decoration_id)
    if not state.is_empty():
        state["grid_position"] = [anchor.x, anchor.y]
        state["rotation_degrees"] = posmod(rotation, 360)
    if decoration_views.has(decoration_id):
        update_decoration_preview_transform(decoration_views[decoration_id], anchor, rotation)

func move_decoration(decoration_id: String, new_anchor: Vector2i, rotation: int) -> bool:
    var token := grid.begin_move(decoration_id)
    if token.is_empty(): return false
    if not grid.commit_move(decoration_id, new_anchor, Vector2i.ONE, rotation):
        grid.cancel_move(token); return false
    for state_variant in GameState.city_state.get("decorations", []):
        var state: Dictionary = state_variant
        if String(state.get("instance_id", "")) == decoration_id:
            state["grid_position"] = [new_anchor.x, new_anchor.y]; state["rotation_degrees"] = posmod(rotation, 360)
    if decoration_views.has(decoration_id):
        decoration_views[decoration_id].global_position = grid.grid_to_world(new_anchor); decoration_views[decoration_id].rotation_degrees.y = rotation
    SaveService.write_current(); return true

func remove_decoration(decoration_id: String) -> bool:
    var decorations: Array = GameState.city_state.get("decorations", [])
    for index in range(decorations.size() - 1, -1, -1):
        if String(decorations[index].get("instance_id", "")) == decoration_id:
            decorations.remove_at(index); grid.release(decoration_id)
            if decoration_views.has(decoration_id): decoration_views[decoration_id].queue_free(); decoration_views.erase(decoration_id)
            SaveService.write_current(); return true
    return false

func get_active_building_levels() -> Dictionary:
    var levels := {}
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        if String(instance.get("state", "")) != "ACTIVE":
            continue
        var building_id := String(instance.get("building_id", ""))
        levels[building_id] = maxi(int(levels.get(building_id, 0)), int(instance.get("level", 0)))
    return levels

func get_build_status(building_id: String) -> Dictionary:
    var definition: Dictionary = building_definitions.get(building_id, {})
    if definition.is_empty(): return {"available": false}
    var count := 0
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        if String(instance.get("building_id", "")) == building_id and String(instance.get("state", "")) != "DISABLED": count += 1
    var levels: Array = definition.get("levels", [])
    var cost: Dictionary = levels[0].get("cost", {}) if not levels.is_empty() else {}
    var available := count < int(definition.get("max_count", 99)) and construction.can_start_build(definition, get_citadel_level(), get_population_current(), get_active_building_levels()) and economy.can_afford(cost)
    return {"available": available, "count": count, "max_count": int(definition.get("max_count", 99)), "cost": cost}

func can_confirm_build(definition: Dictionary) -> bool:
    return bool(get_build_status(String(definition.get("id", ""))).get("available", false))

func get_citadel_level() -> int:
    return _highest_active_building_level("building_royal_citadel")

func get_population_current() -> int:
    return int(GameState.city_state.get("population", {}).get("current", 0))

func confirm_placement() -> bool:
    var confirmed := false
    if build_mode.mode == "BUILD":
        confirmed = build_mode.confirm_build()
    elif build_mode.mode == "MOVE":
        confirmed = build_mode.confirm_move()
    elif build_mode.mode == "DECORATION":
        confirmed = build_mode.confirm_decoration()
    elif build_mode.mode == "MOVE_DECORATION":
        confirmed = build_mode.confirm_move_decoration()
    hud.refresh_placement_mode(build_mode.mode)
    return confirmed

func cancel_placement() -> void:
    build_mode.cancel_build()
    hud.refresh_placement_mode(build_mode.mode)

func rotate_placement() -> void:
    build_mode.rotate_preview()
    hud.refresh_placement_mode(build_mode.mode)

func goto_world_hook() -> void:
    SceneRouter.goto_world()

func _highest_active_building_level(building_id: String) -> int:
    var result := 0
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant
        if String(instance.get("building_id", "")) == building_id and String(instance.get("state", "")) == "ACTIVE": result = maxi(result, int(instance.get("level", 0)))
    return result

func _instances_by_id() -> Dictionary:
    var result := {}
    for instance_variant in GameState.city_state.get("buildings", []):
        var instance: Dictionary = instance_variant; result[String(instance.get("instance_id", ""))] = instance
    return result

func _footprint(definition: Dictionary) -> Vector2i:
    var f: Array = definition.get("footprint", [1, 1]); return Vector2i(int(f[0]), int(f[1]))

func _sync_building_view(instance_id: String) -> void:
    if building_views.has(instance_id): building_views[instance_id].sync_state(get_building_state(instance_id))

func _spawn_decoration_from_state(state: Dictionary) -> void:
    var decoration_id := String(state.get("instance_id", "")); var asset_id := String(state.get("asset_id", ""))
    var gp: Array = state.get("grid_position", [0, 0]); var anchor := Vector2i(int(gp[0]), int(gp[1]))
    if not grid.records.has(decoration_id) and not grid.occupy(decoration_id, anchor, Vector2i.ONE, int(state.get("rotation_degrees", 0))): return
    var path := DataRegistry.asset_service.get_lod(asset_id, 0)
    if path.is_empty(): return
    var packed = load("res://%s" % path)
    if not (packed is PackedScene): return
    var wrapper := Node3D.new(); wrapper.name = decoration_id; wrapper.global_position = grid.grid_to_world(anchor); wrapper.rotation_degrees.y = float(state.get("rotation_degrees", 0))
    var visual := packed.instantiate() as Node3D; visual.scale = Vector3.ONE * 1.8; wrapper.add_child(visual); decoration_root.add_child(wrapper); decoration_views[decoration_id] = wrapper

func _update_lods() -> void:
    for view_variant in building_views.values():
        var view := view_variant as CityBuildingView
        if view != null: view.update_lod(camera.global_position.distance_to(view.global_position))

func _unhandled_input(event: InputEvent) -> void:
    if build_mode.mode != "NONE":
        if event is InputEventMouseMotion:
            var mouse_world = _screen_to_ground(event.position)
            if mouse_world != null:
                build_mode.update_preview_world(mouse_world)
        elif event is InputEventScreenDrag:
            var drag_world = _screen_to_ground(event.position)
            if drag_world != null:
                build_mode.update_preview_world(drag_world)
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            var click_world = _screen_to_ground(event.position)
            if click_world != null:
                build_mode.update_preview_world(click_world)
        elif event is InputEventScreenTouch and event.pressed:
            var touch_world = _screen_to_ground(event.position)
            if touch_world != null:
                build_mode.update_preview_world(touch_world)
        elif event is InputEventKey and event.pressed:
            if event.keycode == KEY_ESCAPE:
                cancel_placement()
            elif event.keycode == KEY_R:
                rotate_placement()
            elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
                confirm_placement()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _try_select(event.position)
    elif event is InputEventScreenTouch and event.pressed and event.index == 0:
        _try_select(event.position)

func _screen_to_ground(screen_position: Vector2):
    var ray_origin := camera.project_ray_origin(screen_position); var ray_direction := camera.project_ray_normal(screen_position)
    return Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)

func _try_select(screen_position: Vector2) -> void:
    var origin_ray := camera.project_ray_origin(screen_position); var direction := camera.project_ray_normal(screen_position)
    var query := PhysicsRayQueryParameters3D.create(origin_ray, origin_ray + direction * 500.0, selection_mask)
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or not (hit.get("collider") is CityBuildingView): deselect(); return
    select_building(hit["collider"])

func select_building(building: CityBuildingView) -> void:
    if selected_view != null and selected_view != building: selected_view.deselect()
    selected_view = building; selected_view.select(); hud.show_building(get_building_view_model(selected_view.instance_id))

func deselect() -> void:
    if selected_view != null: selected_view.deselect(); selected_view = null
    hud.show_building({})

func focus_selected() -> void:
    if selected_view != null: camera_root.focus_target(selected_view.global_position)
