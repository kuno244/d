class_name WorldMinimap
extends Control

var center_cell := Vector2i.ZERO
var world_size := Vector2i(1024, 1024)
var entities: Array = []
var explored_chunks: Array = []

func set_state(new_center: Vector2i, new_world_size: Vector2i, new_entities: Array, explored: Array) -> void:
    center_cell = new_center
    world_size = Vector2i(maxi(1, new_world_size.x), maxi(1, new_world_size.y))
    entities = new_entities
    explored_chunks = explored
    queue_redraw()

func _draw() -> void:
    var bounds := Rect2(Vector2(4, 4), size - Vector2(8, 8))
    draw_rect(bounds, Color("132632"), true)
    for index in range(1, 8):
        var ratio := float(index) / 8.0
        var line_color := Color(0.38, 0.55, 0.56, 0.18)
        draw_line(Vector2(bounds.position.x + bounds.size.x * ratio, bounds.position.y), Vector2(bounds.position.x + bounds.size.x * ratio, bounds.end.y), line_color, 1.0)
        draw_line(Vector2(bounds.position.x, bounds.position.y + bounds.size.y * ratio), Vector2(bounds.end.x, bounds.position.y + bounds.size.y * ratio), line_color, 1.0)
    for chunk_variant in explored_chunks:
        if not (chunk_variant is Array) or chunk_variant.size() < 2: continue
        var chunk := Vector2(float(chunk_variant[0]), float(chunk_variant[1]))
        var chunk_count := Vector2(maxf(1.0, float(world_size.x) / 32.0), maxf(1.0, float(world_size.y) / 32.0))
        var chunk_pos := bounds.position + Vector2(chunk.x / chunk_count.x, chunk.y / chunk_count.y) * bounds.size
        var chunk_size_px := bounds.size / chunk_count
        draw_rect(Rect2(chunk_pos, chunk_size_px + Vector2.ONE), Color(0.34, 0.64, 0.59, 0.17), true)
    for entity_variant in entities:
        if not (entity_variant is Dictionary): continue
        var entity: Dictionary = entity_variant
        var cell: Array = entity.get("cell", [0, 0])
        if cell.size() < 2: continue
        var normalized := Vector2(float(cell[0]) / float(world_size.x - 1), float(cell[1]) / float(world_size.y - 1))
        var position_2d := bounds.position + normalized * bounds.size
        var kind := String(entity.get("kind", ""))
        var radius := 1.2
        var color := Color("7fbf8a")
        match kind:
            "CITY": radius = 4.5; color = Color("f2c14e")
            "FORTRESS": radius = 3.2; color = Color("8ba4d9")
            "PVE", "MONSTER_CAMP": radius = 1.8; color = Color("df626a")
            "RUINS": radius = 1.8; color = Color("ae94dc")
            "VILLAGE": radius = 1.8; color = Color("e7a961")
        draw_circle(position_2d, radius, color)
    var player_normalized := Vector2(float(center_cell.x) / float(world_size.x - 1), float(center_cell.y) / float(world_size.y - 1))
    var player_position := bounds.position + player_normalized * bounds.size
    draw_circle(player_position, 6.5, Color(0.98, 0.88, 0.47, 0.22))
    draw_circle(player_position, 3.2, Color("fff1a8"))
    draw_rect(bounds, Color(0.63, 0.76, 0.72, 0.7), false, 2.0)
