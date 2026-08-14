class_name CityGridService
extends RefCounted

var width: int = 32
var height: int = 32
var cell_size: float = 2.0
var origin := Vector2(-32.0, -32.0)
var occupied: Dictionary = {}
var reservations: Dictionary = {}
var records: Dictionary = {}

func configure(grid_config: Dictionary) -> void:
    width = maxi(1, int(grid_config.get("width", 32)))
    height = maxi(1, int(grid_config.get("height", 32)))
    cell_size = maxf(0.01, float(grid_config.get("cell_size", 2.0)))
    var o: Array = grid_config.get("origin", [-32.0, 0.0, -32.0])
    origin = Vector2(float(o[0]), float(o[2] if o.size() > 2 else o[1]))
    occupied.clear()
    reservations.clear()
    records.clear()

func world_to_grid(world_position: Vector3) -> Vector2i:
    return Vector2i(floori((world_position.x - origin.x) / cell_size), floori((world_position.z - origin.y) / cell_size))

func grid_to_world(cell: Vector2i) -> Vector3:
    return Vector3(origin.x + (cell.x + 0.5) * cell_size, 0.0, origin.y + (cell.y + 0.5) * cell_size)

func rotated_footprint_size(footprint: Vector2i, rotation_degrees: int = 0) -> Vector2i:
    var rotation := posmod(rotation_degrees, 360)
    if rotation == 90 or rotation == 270:
        return Vector2i(footprint.y, footprint.x)
    return footprint

func footprint_world_center(anchor: Vector2i, footprint: Vector2i, rotation_degrees: int = 0) -> Vector3:
    var effective := rotated_footprint_size(footprint, rotation_degrees)
    var first_center := grid_to_world(anchor)
    return first_center + Vector3(
        float(effective.x - 1) * cell_size * 0.5,
        0.0,
        float(effective.y - 1) * cell_size * 0.5
    )

func footprint_cells(anchor: Vector2i, footprint: Vector2i, rotation_degrees: int = 0) -> Array[Vector2i]:
    var effective := rotated_footprint_size(footprint, rotation_degrees)
    var result: Array[Vector2i] = []
    for y in range(effective.y):
        for x in range(effective.x):
            result.append(anchor + Vector2i(x, y))
    return result

func can_place(anchor: Vector2i, footprint: Vector2i, rotation_degrees: int = 0, ignore_instance_id: String = "") -> bool:
    for cell in footprint_cells(anchor, footprint, rotation_degrees):
        if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
            return false
        var owner := String(occupied.get(cell, ""))
        if not owner.is_empty() and owner != ignore_instance_id:
            return false
        var reservation := String(reservations.get(cell, ""))
        if not reservation.is_empty() and reservation != ignore_instance_id:
            return false
    return true

func occupy(instance_id: String, anchor: Vector2i, footprint: Vector2i, rotation_degrees: int = 0) -> bool:
    if records.has(instance_id) or not can_place(anchor, footprint, rotation_degrees):
        return false
    records[instance_id] = {"instance_id": instance_id, "anchor": anchor, "footprint": footprint, "rotation": posmod(rotation_degrees, 360)}
    for cell in footprint_cells(anchor, footprint, rotation_degrees):
        occupied[cell] = instance_id
    return true

func release(instance_id: String) -> bool:
    if not records.has(instance_id):
        return false
    for cell in occupied.keys():
        if String(occupied[cell]) == instance_id:
            occupied.erase(cell)
    records.erase(instance_id)
    return true

func reserve(reservation_id: String, anchor: Vector2i, footprint: Vector2i, rotation_degrees: int = 0) -> bool:
    if not can_place(anchor, footprint, rotation_degrees):
        return false
    for cell in footprint_cells(anchor, footprint, rotation_degrees):
        reservations[cell] = reservation_id
    return true

func release_reservation(reservation_id: String) -> void:
    for cell in reservations.keys():
        if String(reservations[cell]) == reservation_id:
            reservations.erase(cell)

func begin_move(instance_id: String) -> Dictionary:
    if not records.has(instance_id):
        return {}
    var token: Dictionary = records[instance_id].duplicate(true)
    release(instance_id)
    return token

func commit_move(instance_id: String, anchor: Vector2i, footprint: Vector2i, rotation_degrees: int = 0) -> bool:
    return occupy(instance_id, anchor, footprint, rotation_degrees)

func cancel_move(token: Dictionary) -> bool:
    if token.is_empty():
        return false
    return occupy(String(token.get("instance_id", "")), token.get("anchor", Vector2i.ZERO), token.get("footprint", Vector2i.ONE), int(token.get("rotation", 0)))
