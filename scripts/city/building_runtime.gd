class_name CityBuildingView
extends StaticBody3D

var instance_id: String = ""
var building_id: String = ""
var display_name: String = ""
var level: int = 0
var state: String = "PLACING"
var selected := false
var _asset_service: AssetService
var _definition: Dictionary = {}
var _grid: CityGridService
var _lod_profiles: Dictionary = {}
var _current_lod := -1
var _visual: Node3D
var _visual_scale := 1.0

@onready var visual_root: Node3D = $VisualRoot
@onready var selection_marker: MeshInstance3D = $SelectionMarker

func configure(instance_data: Dictionary, definition: Dictionary, asset_service: AssetService, grid: CityGridService, lod_profiles: Dictionary) -> void:
    instance_id = String(instance_data.get("instance_id", ""))
    building_id = String(instance_data.get("building_id", ""))
    display_name = String(definition.get("display_name", building_id))
    level = int(instance_data.get("level", 0))
    state = String(instance_data.get("state", "PLACING"))
    _definition = definition
    _asset_service = asset_service
    _grid = grid
    _lod_profiles = lod_profiles
    var grid_pos: Array = instance_data.get("grid_position", [0, 0])
    set_grid_transform(Vector2i(int(grid_pos[0]), int(grid_pos[1])), int(instance_data.get("rotation_degrees", 0)))
    _visual_scale = _calculate_visual_scale()
    _build_collision()
    _resize_selection_marker()
    _load_lod(0)

func sync_state(instance_data: Dictionary) -> void:
    level = int(instance_data.get("level", level))
    state = String(instance_data.get("state", state))
    var grid_pos: Array = instance_data.get("grid_position", [0, 0])
    set_grid_transform(Vector2i(int(grid_pos[0]), int(grid_pos[1])), int(instance_data.get("rotation_degrees", 0)))

func set_grid_transform(anchor: Vector2i, rotation: int) -> void:
    var footprint_data: Array = _definition.get("footprint", [1, 1])
    var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
    global_position = _grid.footprint_world_center(anchor, footprint, rotation)
    rotation_degrees.y = float(rotation)

func select() -> void:
    selected = true
    selection_marker.visible = true
    EventHub.building_selected.emit(building_id)
    EventHub.building_instance_selected.emit(instance_id, building_id)

func deselect() -> void:
    if selected:
        selected = false
        selection_marker.visible = false
        EventHub.building_deselected.emit()

func set_placement_feedback(valid: bool) -> void:
    selection_marker.visible = true
    var material := selection_marker.material_override as StandardMaterial3D
    if material != null:
        material.albedo_color = Color(0.18, 0.9, 0.35, 0.42) if valid else Color(0.95, 0.2, 0.18, 0.46)

func clear_placement_feedback() -> void:
    selection_marker.visible = selected

func update_lod(camera_distance: float) -> void:
    if _asset_service == null:
        return
    var profile_name := _lod_profile_name()
    var profile: Dictionary = _lod_profiles.get(profile_name, {"lod0_max_distance": 25.0, "lod1_max_distance": 55.0})
    var desired := 0
    if camera_distance > float(profile.get("lod1_max_distance", 55.0)):
        desired = 2
    elif camera_distance > float(profile.get("lod0_max_distance", 25.0)):
        desired = 1
    if desired != _current_lod:
        _load_lod(desired)

func _lod_profile_name() -> String:
    if building_id in ["building_royal_citadel", "building_grand_academy", "building_alliance_hall"]:
        return "important_building"
    return "ordinary_building"

func _load_lod(level_index: int) -> void:
    var path := _asset_service.get_lod(building_id, level_index)
    if path.is_empty():
        return
    var resource = load("res://%s" % path)
    if not (resource is PackedScene):
        return
    if _visual != null and is_instance_valid(_visual):
        _visual.queue_free()
    _visual = resource.instantiate()
    _visual.scale = Vector3.ONE * _visual_scale
    visual_root.add_child(_visual)
    _current_lod = level_index

func _calculate_visual_scale() -> float:
    var footprint: Array = _definition.get("footprint", [2, 2])
    var desired_x := float(footprint[0]) * _grid.cell_size * 0.88
    var desired_z := float(footprint[1]) * _grid.cell_size * 0.88
    var collision := _asset_service.get_collision_definition(building_id)
    var boxes: Array = collision.get("boxes", [])
    if boxes.is_empty():
        return 1.0
    var size: Array = boxes[0].get("size", [1.0, 1.0, 1.0])
    return minf(desired_x / maxf(0.01, float(size[0])), desired_z / maxf(0.01, float(size[2])))

func _build_collision() -> void:
    for child in get_children():
        if child is CollisionShape3D:
            child.queue_free()
    var collision := _asset_service.get_collision_definition(building_id)
    for box_variant in collision.get("boxes", []):
        var box: Dictionary = box_variant
        var shape := BoxShape3D.new()
        var size: Array = box.get("size", [1.0, 1.0, 1.0])
        shape.size = Vector3(float(size[0]), float(size[1]), float(size[2])) * _visual_scale
        var node := CollisionShape3D.new()
        node.shape = shape
        var center: Array = box.get("center", [0.0, 0.0, 0.0])
        node.position = Vector3(float(center[0]), float(center[1]), float(center[2])) * _visual_scale
        add_child(node)

func _resize_selection_marker() -> void:
    var footprint: Array = _definition.get("footprint", [2, 2])
    var mesh := selection_marker.mesh as BoxMesh
    if mesh != null:
        mesh.size = Vector3(float(footprint[0]) * _grid.cell_size, 0.08, float(footprint[1]) * _grid.cell_size)
