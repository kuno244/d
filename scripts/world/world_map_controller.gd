class_name WorldMapController
extends Node3D

@onready var camera_root: WorldMapCameraController = $WorldMapCameraController
@onready var terrain_root: Node3D = $TerrainRoot
@onready var prop_root: Node3D = $PropRoot
@onready var entity_root: Node3D = $EntityRoot
@onready var hud: WorldHUD = $UIRoot/WorldHUD

var world_service := WorldService.new()
var world_config: Dictionary = {}
var active_chunks: Dictionary = {}
var entity_views: Dictionary = {}
var selected_view: WorldEntityView
var selected_entity_id := ""
var cell_size := 6.0
var chunk_size := 8
var chunk_radius := 2
var refresh_accumulator := 0.0

func _ready() -> void:
    if not DataRegistry.initialized:
        var errors := DataRegistry.initialize()
        if not errors.is_empty():
            push_error("World cannot initialize DataRegistry: %s" % errors)
            return
    world_config = DataRegistry.data.get("world", {}).get("world", {})
    cell_size = float(world_config.get("cell_size", 6.0))
    chunk_size = int(world_config.get("chunk_size", 8))
    chunk_radius = int(world_config.get("performance", {}).get("visible_chunk_radius", 2))
    world_service.configure(GameState.world_state, world_config, GameState.resources, GameState.capacities)
    var generated := world_service.ensure_generated()
    var offline_changes := world_service.process_offline(GameClock.unix_time())
    camera_root.configure(int(GameState.world_state.get("width", 64)), int(GameState.world_state.get("height", 64)), cell_size, GameState.world_state.get("camera", {}))
    camera_root.camera_moved.connect(_on_camera_moved)
    hud.action_requested.connect(_on_action_requested)
    hud.city_requested.connect(_on_city_requested)
    hud.center_army_requested.connect(_on_center_army_requested)
    refresh_visible_chunks(camera_root.get_center_cell())
    _refresh_hud()
    if generated: hud.toast("A new realm has been charted from seed %d" % int(GameState.world_state.get("seed", 0)))
    elif offline_changes > 0: hud.toast("%d world sites respawned while you were away" % offline_changes)
    SaveService.write_current()

func _process(delta: float) -> void:
    refresh_accumulator += delta
    if refresh_accumulator >= 0.35:
        refresh_accumulator = 0.0
        refresh_visible_chunks(camera_root.get_center_cell())
        _refresh_hud()

func _exit_tree() -> void:
    if camera_root != null:
        GameState.world_state["camera"] = camera_root.get_camera_state()
        SaveService.write_current()

func refresh_visible_chunks(center_cell: Vector2i) -> void:
    var max_chunks_x := int(ceil(float(GameState.world_state.get("width", 64)) / float(chunk_size)))
    var max_chunks_y := int(ceil(float(GameState.world_state.get("height", 64)) / float(chunk_size)))
    var center_chunk := Vector2i(center_cell.x / chunk_size, center_cell.y / chunk_size)
    var desired: Dictionary = {}
    for y in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
        for x in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
            if x < 0 or y < 0 or x >= max_chunks_x or y >= max_chunks_y: continue
            var chunk := Vector2i(x, y)
            desired[_chunk_key(chunk)] = chunk
    for key in active_chunks.keys():
        if not desired.has(key):
            active_chunks[key].queue_free(); active_chunks.erase(key)
    for key in desired.keys():
        if not active_chunks.has(key): active_chunks[key] = _spawn_chunk(desired[key])
    world_service.reveal_around(center_cell, chunk_radius)
    _refresh_entity_views(desired)

func select_entity(entity_id: String) -> void:
    if selected_view != null: selected_view.set_selected(false)
    selected_entity_id = entity_id
    selected_view = entity_views.get(entity_id) as WorldEntityView
    if selected_view != null: selected_view.set_selected(true)
    var entity := world_service.get_entity(entity_id)
    hud.show_entity(entity, _entity_display_name(entity))

func _spawn_chunk(chunk: Vector2i) -> Node3D:
    var container := Node3D.new(); container.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
    var mesh_instance := MeshInstance3D.new(); mesh_instance.name = "Terrain"
    var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var seed_value := int(GameState.world_state.get("seed", 0))
    var width := int(GameState.world_state.get("width", 64)); var height := int(GameState.world_state.get("height", 64))
    for local_y in range(chunk_size):
        for local_x in range(chunk_size):
            var cell := Vector2i(chunk.x * chunk_size + local_x, chunk.y * chunk_size + local_y)
            if cell.x >= width or cell.y >= height: continue
            var color := _biome_color(world_service.generator.biome_at(cell, seed_value))
            var center := cell_to_world(cell)
            var half := cell_size * 0.51
            var a := Vector3(center.x - half, 0.0, center.z - half)
            var b := Vector3(center.x + half, 0.0, center.z - half)
            var c := Vector3(center.x + half, 0.0, center.z + half)
            var d := Vector3(center.x - half, 0.0, center.z + half)
            _surface_triangle(surface, a, b, c, color)
            _surface_triangle(surface, a, c, d, color)
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true; material.roughness = 1.0
    mesh_instance.mesh = surface.commit(); mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    container.add_child(mesh_instance)
    terrain_root.add_child(container)
    _spawn_chunk_props(chunk, container)
    return container

func _spawn_chunk_props(chunk: Vector2i, container: Node3D) -> void:
    var props := Node3D.new(); props.name = "BatchedProps"; container.add_child(props)
    var hash_value: int = absi((chunk.x * 92821) ^ (chunk.y * 68917) ^ int(GameState.world_state.get("seed", 0)))
    var prop_count: int = 1 + hash_value % 2
    for index in range(prop_count):
        var asset_id := "world_stylized_tree" if (hash_value + index) % 3 != 0 else "world_rock_cluster"
        var path := DataRegistry.asset_service.get_lod(asset_id, 2)
        if path.is_empty(): continue
        var packed = load("res://%s" % path)
        if not (packed is PackedScene): continue
        var visual := packed.instantiate() as Node3D
        var cell := Vector2i(chunk.x * chunk_size + posmod(hash_value + index * 3, chunk_size), chunk.y * chunk_size + posmod(int(hash_value / 7) + index * 5, chunk_size))
        visual.position = cell_to_world(cell) + Vector3(1.4, 0.12, -1.1)
        visual.rotation_degrees.y = float(posmod(hash_value + index * 71, 360))
        visual.scale = Vector3.ONE * (3.2 if asset_id == "world_stylized_tree" else 2.6)
        props.add_child(visual)

func _refresh_entity_views(desired_chunks: Dictionary) -> void:
    var visible_ids: Dictionary = {}
    var visible_budget := int(world_config.get("performance", {}).get("max_visible_entities", 90))
    for entity_variant in GameState.world_state.get("entities", []):
        if not (entity_variant is Dictionary) or visible_ids.size() >= visible_budget: continue
        var entity: Dictionary = entity_variant
        var cell_data: Array = entity.get("cell", [0, 0])
        var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
        var chunk := Vector2i(cell.x / chunk_size, cell.y / chunk_size)
        if not desired_chunks.has(_chunk_key(chunk)): continue
        var entity_id := String(entity.get("entity_id", "")); visible_ids[entity_id] = true
        if not entity_views.has(entity_id):
            var view := WorldEntityView.new(); entity_root.add_child(view)
            view.position = cell_to_world(cell) + Vector3(0.0, 0.18, 0.0)
            view.configure(entity, _entity_display_name(entity))
            view.selected.connect(select_entity)
            entity_views[entity_id] = view
            if String(entity.get("kind", "")) == "CITY": _attach_city_visual(view)
    for entity_id in entity_views.keys():
        if not visible_ids.has(entity_id):
            if selected_entity_id == entity_id:
                selected_entity_id = ""; selected_view = null; hud.clear_entity()
            entity_views[entity_id].queue_free(); entity_views.erase(entity_id)

func _attach_city_visual(view: WorldEntityView) -> void:
    var path := DataRegistry.asset_service.get_lod("building_royal_citadel", 2)
    if path.is_empty(): return
    var packed = load("res://%s" % path)
    if not (packed is PackedScene): return
    var visual := packed.instantiate() as Node3D
    visual.scale = Vector3.ONE * 4.8; visual.position.y = 0.2
    view.add_child(visual); view.move_child(visual, 0)

func _on_action_requested(action: String, entity_id: String) -> void:
    var now := GameClock.unix_time()
    match action:
        "ENTER_CITY": _on_city_requested()
        "GATHER":
            var entity := world_service.get_entity(entity_id)
            var amount := world_service.gather(entity_id, 250 + int(entity.get("level", 1)) * 75, now)
            hud.toast("Gathered %d %s" % [amount, String(entity.get("resource_type", "resource")).capitalize()] if amount > 0 else "Gathering unavailable or storage full")
            _refresh_selected()
        "EXPLORE":
            var reward := world_service.explore(entity_id)
            hud.toast("Ruins explored • %s" % _reward_text(reward) if not reward.is_empty() else "Ruins already explored")
            _refresh_selected()
        "TRADE":
            var reward := world_service.trade(entity_id)
            hud.toast("Village trade • %s" % _reward_text(reward))
            _refresh_selected()
        "ATTACK":
            var battle := world_service.prepare_battle(entity_id)
            if battle.is_empty(): hud.toast("Target is not available")
            else:
                SaveService.write_current(); SceneRouter.goto_battle(); return
        "INSPECT": hud.toast("Fortress topology ready for the future territory campaign")
    SaveService.write_current(); _refresh_hud()

func _on_city_requested() -> void:
    GameState.world_state["camera"] = camera_root.get_camera_state()
    SaveService.write_current(); SceneRouter.goto_city()

func _on_center_army_requested() -> void:
    var army := world_service.get_army()
    var cell_data: Array = army.get("cell", GameState.world_state.get("player_city_cell", [32, 32]))
    camera_root.focus_cell(Vector2i(int(cell_data[0]), int(cell_data[1])))
    hud.toast("Centered on Crown Vanguard")

func _on_camera_moved(cell: Vector2i) -> void:
    refresh_visible_chunks(cell)

func _refresh_hud() -> void:
    hud.set_resources(GameState.resources, GameState.capacities)
    var cell := camera_root.get_center_cell()
    var region_size := int(GameState.world_state.get("region_size", 16))
    var region := Vector2i(cell.x / region_size, cell.y / region_size)
    var biome_id := world_service.generator.biome_at(cell, int(GameState.world_state.get("seed", 0)))
    var biome_def := world_service.generator.biome_definition(biome_id)
    hud.set_location(cell, region, String(biome_def.get("display_name", biome_id.capitalize())), camera_root.get_zoom_tier())
    hud.set_objective(int(GameState.world_state.get("objectives", {}).get("step", 0)))

func _refresh_selected() -> void:
    if selected_entity_id.is_empty(): return
    var entity := world_service.get_entity(selected_entity_id)
    hud.show_entity(entity, _entity_display_name(entity))

func _entity_display_name(entity: Dictionary) -> String:
    var kind := String(entity.get("kind", ""))
    match kind:
        "CITY": return String(entity.get("display_name", "Crownkeep"))
        "RESOURCE": return "%s Deposit" % String(entity.get("resource_type", "Resource")).capitalize()
        "PVE":
            var definition := DataRegistry.get_definition("pve", String(entity.get("pve_id", "")))
            return String(definition.get("display_name", "Hostile Creature"))
        "MONSTER_CAMP": return "Monster Camp"
        "RUINS": return "Ancient Ruins"
        "VILLAGE": return "Neutral Village"
        "FORTRESS": return "Alliance Fortress"
        _: return kind.capitalize()

func cell_to_world(cell: Vector2i) -> Vector3:
    var width := int(GameState.world_state.get("width", 64)); var height := int(GameState.world_state.get("height", 64))
    return Vector3((float(cell.x) - float(width - 1) * 0.5) * cell_size, 0.0, (float(cell.y) - float(height - 1) * 0.5) * cell_size)

func _surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
    for vertex in [a, b, c]:
        surface.set_normal(Vector3.UP); surface.set_color(color); surface.add_vertex(vertex)

func _biome_color(biome_id: String) -> Color:
    var definition := world_service.generator.biome_definition(biome_id)
    return Color.html(String(definition.get("color", "78a75a"))).darkened(0.08)

func _chunk_key(chunk: Vector2i) -> String:
    return "%d:%d" % [chunk.x, chunk.y]

func _reward_text(reward: Dictionary) -> String:
    var parts: Array[String] = []
    for resource_id in ["food", "wood", "stone", "gold"]:
        if int(reward.get(resource_id, 0)) > 0: parts.append("%d %s" % [int(reward[resource_id]), resource_id.capitalize()])
    return ", ".join(parts)
