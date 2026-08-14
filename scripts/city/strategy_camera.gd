class_name StrategyCamera
extends Node3D

@export var move_speed: float = 16.0
@export var drag_sensitivity: float = 0.035
@export var inertia_decay: float = 7.0
@export var zoom_speed: float = 3.0
@export var zoom_smoothing: float = 10.0
@export var min_zoom: float = 8.0
@export var max_zoom: float = 32.0
@export var camera_bounds := Rect2(-45.0, -45.0, 90.0, 90.0)

@onready var camera: Camera3D = $Camera3D
var _pan_velocity := Vector2.ZERO
var _zoom_target: float = 18.0
var _touches: Dictionary = {}
var _last_pinch_distance: float = 0.0

func _ready() -> void:
    _ensure_desktop_actions()
    _zoom_target = clampf(camera.position.y, min_zoom, max_zoom)

func _ensure_desktop_actions() -> void:
    _ensure_key_action("camera_left", KEY_A)
    _ensure_key_action("camera_right", KEY_D)
    _ensure_key_action("camera_forward", KEY_W)
    _ensure_key_action("camera_back", KEY_S)

func _ensure_key_action(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).is_empty():
        var event := InputEventKey.new()
        event.physical_keycode = keycode
        InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
    # Input axis contract: A/left is negative X, D/right is positive X.
    var keyboard := Vector2.ZERO
    if Input.is_action_pressed("camera_left"):
        keyboard += Vector2(-1.0, 0.0)
    if Input.is_action_pressed("camera_right"):
        keyboard += Vector2(1.0, 0.0)
    if Input.is_action_pressed("camera_forward"):
        keyboard += Vector2(0.0, -1.0)
    if Input.is_action_pressed("camera_back"):
        keyboard += Vector2(0.0, 1.0)
    if keyboard.length_squared() > 0.0:
        _pan_velocity = keyboard.normalized() * move_speed
    else:
        _pan_velocity = _pan_velocity.move_toward(Vector2.ZERO, inertia_decay * move_speed * delta)
    position.x += _pan_velocity.x * delta
    position.z += _pan_velocity.y * delta
    position.x = clampf(position.x, camera_bounds.position.x, camera_bounds.end.x)
    position.z = clampf(position.z, camera_bounds.position.y, camera_bounds.end.y)
    camera.position.y = lerpf(camera.position.y, _zoom_target, 1.0 - exp(-zoom_smoothing * delta))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE or event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
        _pan_velocity = Vector2(-event.relative.x, -event.relative.y) * move_speed * drag_sensitivity
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _set_zoom(_zoom_target - zoom_speed)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _set_zoom(_zoom_target + zoom_speed)
    elif event is InputEventScreenTouch:
        if event.pressed:
            _touches[event.index] = event.position
        else:
            _touches.erase(event.index)
            if _touches.size() < 2:
                _last_pinch_distance = 0.0
    elif event is InputEventScreenDrag:
        _touches[event.index] = event.position
        if _touches.size() == 1:
            _pan_velocity = Vector2(-event.relative.x, -event.relative.y) * move_speed * drag_sensitivity
        elif _touches.size() == 2:
            var points := _touches.values()
            var distance := Vector2(points[0]).distance_to(Vector2(points[1]))
            if _last_pinch_distance > 0.0:
                _set_zoom(_zoom_target - (distance - _last_pinch_distance) * 0.02)
            _last_pinch_distance = distance
    elif event is InputEventMagnifyGesture:
        _set_zoom(_zoom_target / maxf(event.factor, 0.01))

func _set_zoom(value: float) -> void:
    _zoom_target = clampf(value, min_zoom, max_zoom)

func focus_target(world_position: Vector3) -> void:
    var target := Vector3(
        clampf(world_position.x, camera_bounds.position.x, camera_bounds.end.x),
        position.y,
        clampf(world_position.z, camera_bounds.position.y, camera_bounds.end.y)
    )
    var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "position", target, 0.35)
