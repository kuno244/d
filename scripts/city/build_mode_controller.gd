class_name BuildModeController
extends Node

signal mode_changed(mode: String)
signal placement_feedback(valid: bool)

var city: Node
var grid: CityGridService
var construction: ConstructionService
var mode := "NONE"
var building_definition: Dictionary = {}
var preview: CityBuildingView
var decoration_preview: Node3D
var preview_anchor := Vector2i.ZERO
var preview_rotation := 0
var preview_valid := false
var move_token: Dictionary = {}
var moving_instance_id := ""

func configure(city_controller: Node, grid_service: CityGridService, construction_service: ConstructionService) -> void:
    city = city_controller
    grid = grid_service
    construction = construction_service

func begin_build(building_id: String) -> bool:
    if mode != "NONE":
        cancel_build()
    var definition: Dictionary = DataRegistry.get_definition("buildings", building_id)
    if definition.is_empty() or not bool(city.get_build_status(building_id).get("available", false)):
        return false
    mode = "BUILD"
    building_definition = definition
    preview_rotation = 0
    preview_anchor = Vector2i(grid.width / 2, grid.height / 2)
    preview = city.create_preview_view(building_id, preview_anchor, preview_rotation)
    _refresh_preview_validity()
    mode_changed.emit(mode)
    return true

func rotate_preview() -> void:
    if mode not in ["BUILD", "MOVE", "DECORATION", "MOVE_DECORATION"]:
        return
    preview_rotation = posmod(preview_rotation + 90, 360)
    _refresh_preview_validity()
    if mode in ["DECORATION", "MOVE_DECORATION"]:
        city.update_decoration_preview_transform(decoration_preview, preview_anchor, preview_rotation)
    elif preview != null:
        city.update_preview_transform(preview, preview_anchor, preview_rotation)

func update_preview_world(world_position: Vector3) -> void:
    if mode not in ["BUILD", "MOVE", "DECORATION", "MOVE_DECORATION"]:
        return
    preview_anchor = grid.world_to_grid(world_position)
    _refresh_preview_validity()
    if mode in ["DECORATION", "MOVE_DECORATION"]:
        city.update_decoration_preview_transform(decoration_preview, preview_anchor, preview_rotation)
    elif preview != null:
        city.update_preview_transform(preview, preview_anchor, preview_rotation)

func confirm_build() -> bool:
    if mode != "BUILD" or not preview_valid:
        return false
    grid.release_reservation("active_preview")
    var instance: Dictionary = city.create_building_state(String(building_definition.get("id", "")), preview_anchor, preview_rotation)
    if instance.is_empty():
        return false
    var footprint := _footprint(building_definition)
    if not grid.occupy(String(instance["instance_id"]), preview_anchor, footprint, preview_rotation):
        _refresh_preview_validity()
        return false
    city.add_building_state(instance)
    if not construction.start_build(building_definition, instance, GameClock.unix_time(), city.get_citadel_level(), city.get_population_current(), city.get_active_building_levels()):
        grid.release(String(instance["instance_id"]))
        city.remove_building_state(String(instance["instance_id"]))
        _refresh_preview_validity()
        return false
    city.spawn_building_view(instance)
    _finish_preview()
    city.refresh_derived_state()
    SaveService.write_current()
    return true

func cancel_build() -> void:
    if mode == "MOVE":
        cancel_move()
        return
    if mode == "MOVE_DECORATION":
        cancel_move_decoration()
        return
    _finish_preview()

func begin_move(instance_id: String) -> bool:
    if mode != "NONE":
        return false
    var instance: Dictionary = city.get_building_state(instance_id)
    if instance.is_empty() or String(instance.get("state", "")) != "ACTIVE":
        return false
    building_definition = DataRegistry.get_definition("buildings", String(instance.get("building_id", "")))
    move_token = grid.begin_move(instance_id)
    if move_token.is_empty():
        return false
    moving_instance_id = instance_id
    mode = "MOVE"
    var gp: Array = instance.get("grid_position", [0, 0])
    preview_anchor = Vector2i(int(gp[0]), int(gp[1]))
    preview_rotation = int(instance.get("rotation_degrees", 0))
    preview = city.get_building_view(instance_id)
    _refresh_preview_validity()
    mode_changed.emit(mode)
    return true

func confirm_move() -> bool:
    if mode != "MOVE" or not preview_valid:
        return false
    grid.release_reservation("active_preview")
    if not grid.commit_move(moving_instance_id, preview_anchor, _footprint(building_definition), preview_rotation):
        _refresh_preview_validity()
        return false
    city.update_building_position(moving_instance_id, preview_anchor, preview_rotation)
    if preview != null:
        preview.clear_placement_feedback()
    move_token.clear()
    moving_instance_id = ""
    preview = null
    decoration_preview = null
    mode = "NONE"
    mode_changed.emit(mode)
    SaveService.write_current()
    return true

func cancel_move() -> bool:
    if mode != "MOVE" or move_token.is_empty():
        return false
    grid.release_reservation("active_preview")
    var restored := grid.cancel_move(move_token)
    if restored:
        var anchor: Vector2i = move_token.get("anchor", Vector2i.ZERO)
        city.update_building_position(moving_instance_id, anchor, int(move_token.get("rotation", 0)))
    if preview != null:
        preview.clear_placement_feedback()
    move_token.clear()
    moving_instance_id = ""
    preview = null
    decoration_preview = null
    mode = "NONE"
    mode_changed.emit(mode)
    return restored

func begin_move_decoration(decoration_id: String) -> bool:
    if mode != "NONE":
        return false
    var state: Dictionary = city.get_decoration_state(decoration_id)
    if state.is_empty():
        return false
    move_token = grid.begin_move(decoration_id)
    if move_token.is_empty():
        return false
    moving_instance_id = decoration_id
    mode = "MOVE_DECORATION"
    var gp: Array = state.get("grid_position", [0, 0])
    preview_anchor = Vector2i(int(gp[0]), int(gp[1]))
    preview_rotation = int(state.get("rotation_degrees", 0))
    decoration_preview = city.get_decoration_view(decoration_id)
    _refresh_preview_validity()
    mode_changed.emit(mode)
    return true

func confirm_move_decoration() -> bool:
    if mode != "MOVE_DECORATION" or not preview_valid:
        return false
    grid.release_reservation("active_preview")
    if not grid.commit_move(moving_instance_id, preview_anchor, Vector2i.ONE, preview_rotation):
        _refresh_preview_validity()
        return false
    city.update_decoration_position(moving_instance_id, preview_anchor, preview_rotation)
    city.clear_decoration_placement_feedback(decoration_preview)
    move_token.clear()
    moving_instance_id = ""
    decoration_preview = null
    mode = "NONE"
    mode_changed.emit(mode)
    SaveService.write_current()
    return true

func cancel_move_decoration() -> bool:
    if mode != "MOVE_DECORATION" or move_token.is_empty():
        return false
    grid.release_reservation("active_preview")
    var restored := grid.cancel_move(move_token)
    if restored:
        var old_anchor: Vector2i = move_token.get("anchor", Vector2i.ZERO)
        city.update_decoration_position(moving_instance_id, old_anchor, int(move_token.get("rotation", 0)))
    city.clear_decoration_placement_feedback(decoration_preview)
    move_token.clear()
    moving_instance_id = ""
    decoration_preview = null
    mode = "NONE"
    mode_changed.emit(mode)
    return restored

func begin_decoration(asset_id: String) -> bool:
    if mode != "NONE" or asset_id not in DataRegistry.data.get("city", {}).get("decoration", {}).get("allowed_asset_ids", []):
        return false
    mode = "DECORATION"
    building_definition = {"id": asset_id, "asset_id": asset_id, "footprint": [1, 1]}
    preview_anchor = Vector2i(grid.width / 2, grid.height / 2)
    preview_rotation = 0
    decoration_preview = city.create_decoration_preview(asset_id, preview_anchor, preview_rotation)
    if decoration_preview == null:
        mode = "NONE"
        building_definition.clear()
        return false
    _refresh_preview_validity()
    mode_changed.emit(mode)
    return true

func confirm_decoration() -> bool:
    if mode != "DECORATION" or not preview_valid:
        return false
    grid.release_reservation("active_preview")
    var ok: bool = bool(city.add_decoration_state(String(building_definition["id"]), preview_anchor, preview_rotation))
    if decoration_preview != null:
        decoration_preview.queue_free()
    decoration_preview = null
    mode = "NONE"
    building_definition.clear()
    mode_changed.emit(mode)
    return ok

func remove_decoration(decoration_id: String) -> bool:
    return city.remove_decoration(decoration_id)

func _refresh_preview_validity() -> void:
    grid.release_reservation("active_preview")
    preview_valid = grid.can_place(preview_anchor, _footprint(building_definition), preview_rotation)
    if mode == "BUILD":
        preview_valid = preview_valid and city.can_confirm_build(building_definition)
    if preview_valid:
        grid.reserve("active_preview", preview_anchor, _footprint(building_definition), preview_rotation)
    if preview != null:
        preview.set_placement_feedback(preview_valid)
    if decoration_preview != null:
        city.set_decoration_placement_feedback(decoration_preview, preview_valid)
    placement_feedback.emit(preview_valid)

func _footprint(definition: Dictionary) -> Vector2i:
    var f: Array = definition.get("footprint", [1, 1])
    return Vector2i(int(f[0]), int(f[1]))

func _finish_preview() -> void:
    grid.release_reservation("active_preview")
    if preview != null and mode == "BUILD":
        preview.queue_free()
    elif preview != null:
        preview.clear_placement_feedback()
    if decoration_preview != null:
        if mode == "DECORATION":
            decoration_preview.queue_free()
        else:
            city.clear_decoration_placement_feedback(decoration_preview)
    preview = null
    decoration_preview = null
    mode = "NONE"
    building_definition.clear()
    preview_valid = false
    mode_changed.emit(mode)
