class_name WorldMapCameraController
extends Node3D

signal camera_moved(cell: Vector2i)

@onready var camera: Camera3D = $Camera3D

var world_width := 1024
var world_height := 1024
var cell_size := 8.0
var zoom_value := 2.0
var target_position := Vector3.ZERO
var velocity := Vector3.ZERO
var dragging := false
var last_mouse := Vector2.ZERO
var touch_points: Dictionary = {}
var previous_pinch_distance := 0.0
var last_reported_cell := Vector2i(-999, -999)

func _ready() -> void:
    _ensure_key_action("camera_left", KEY_A)
    _ensure_key_action("camera_right", KEY_D)
    _ensure_key_action("camera_forward", KEY_W)
    _ensure_key_action("camera_back", KEY_S)

func configure(width: int, height: int, size_per_cell: float, camera_state: Dictionary) -> void:
    world_width = width; world_height = height; cell_size = size_per_cell
    var saved_cell: Array = camera_state.get("cell", [width / 2, height / 2])
    zoom_value = clampf(float(camera_state.get("zoom", 2.0)), 0.28, 3.6)
    position = cell_to_local(Vector2i(int(saved_cell[0]), int(saved_cell[1])))
    target_position = position
    _apply_zoom()

func _process(delta: float) -> void:
    var input_vector := Input.get_vector("camera_left", "camera_right", "camera_forward", "camera_back")
    if input_vector.length_squared() > 0.0:
        velocity += Vector3(input_vector.x, 0.0, input_vector.y) * 112.0 * zoom_value * delta
    target_position += velocity * delta
    velocity = velocity.lerp(Vector3.ZERO, clampf(delta * 5.5, 0.0, 1.0))
    target_position = _clamp_position(target_position)
    position = position.lerp(target_position, clampf(delta * 9.0, 0.0, 1.0))
    var current_cell := get_center_cell()
    if current_cell != last_reported_cell:
        last_reported_cell = current_cell
        camera_moved.emit(current_cell)

func focus_cell(cell: Vector2i, immediate: bool = false) -> void:
    target_position = _clamp_position(cell_to_local(cell))
    if immediate: position = target_position

func jump_to_coordinates(cell: Vector2i) -> void:
    focus_cell(cell)

func get_center_cell() -> Vector2i:
    return local_to_cell(position)

func get_camera_state() -> Dictionary:
    var current := get_center_cell()
    return {"cell": [current.x, current.y], "zoom": zoom_value}

func get_zoom_tier() -> String:
    if zoom_value < 0.78: return "CLOSE"
    if zoom_value < 1.85: return "MEDIUM"
    return "FAR"

func set_overview_zoom() -> void:
    _set_zoom(3.2)

func cell_to_local(cell: Vector2i) -> Vector3:
    return Vector3((float(cell.x) - float(world_width - 1) * 0.5) * cell_size, 0.0, (float(cell.y) - float(world_height - 1) * 0.5) * cell_size)

func local_to_cell(world_position: Vector3) -> Vector2i:
    return Vector2i(
        clampi(roundi(world_position.x / cell_size + float(world_width - 1) * 0.5), 0, world_width - 1),
        clampi(roundi(world_position.z / cell_size + float(world_height - 1) * 0.5), 0, world_height - 1)
    )

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
            dragging = event.pressed; last_mouse = event.position
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(zoom_value * 0.88)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(zoom_value * 1.14)
    elif event is InputEventMouseMotion and dragging:
        _pan_screen_delta(event.position - last_mouse); last_mouse = event.position
    elif event is InputEventScreenTouch:
        if event.pressed: touch_points[event.index] = event.position
        else: touch_points.erase(event.index)
        previous_pinch_distance = _touch_distance() if touch_points.size() == 2 else 0.0
    elif event is InputEventScreenDrag:
        touch_points[event.index] = event.position
        if touch_points.size() == 1:
            _pan_screen_delta(event.relative)
        elif touch_points.size() == 2:
            var current_distance := _touch_distance()
            if previous_pinch_distance > 0.0 and current_distance > 0.0:
                _set_zoom(zoom_value * previous_pinch_distance / current_distance)
            previous_pinch_distance = current_distance
    elif event is InputEventMagnifyGesture:
        _set_zoom(zoom_value / maxf(0.1, event.factor))

func _pan_screen_delta(delta: Vector2) -> void:
    target_position += Vector3(-delta.x, 0.0, -delta.y) * 0.16 * zoom_value
    velocity = Vector3(-delta.x, 0.0, -delta.y) * 0.82 * zoom_value

func _set_zoom(value: float) -> void:
    zoom_value = clampf(value, 0.28, 3.6)
    _apply_zoom()

func _apply_zoom() -> void:
    camera.size = 96.0 * zoom_value

func _touch_distance() -> float:
    var points := touch_points.values()
    return points[0].distance_to(points[1]) if points.size() == 2 else 0.0

func _clamp_position(value: Vector3) -> Vector3:
    var half_x := float(world_width - 1) * cell_size * 0.5
    var half_z := float(world_height - 1) * cell_size * 0.5
    return Vector3(clampf(value.x, -half_x, half_x), 0.0, clampf(value.z, -half_z, half_z))

func _ensure_key_action(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action): InputMap.add_action(action)
    if InputMap.action_get_events(action).is_empty():
        var key_event := InputEventKey.new(); key_event.physical_keycode = keycode
        InputMap.action_add_event(action, key_event)
