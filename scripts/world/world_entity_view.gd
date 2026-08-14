class_name WorldEntityView
extends Area3D

signal selected(entity_id: String)

var entity_id := ""
var kind := ""
var cell := Vector2i.ZERO
var base_color := Color.WHITE
var resolved := false
var subtype := ""

func configure(entity: Dictionary, display_name: String) -> void:
    entity_id = String(entity.get("entity_id", ""))
    kind = String(entity.get("kind", ""))
    subtype = String(entity.get("resource_type", entity.get("pve_id", "")))
    var cell_data: Array = entity.get("cell", [0, 0])
    cell = Vector2i(int(cell_data[0]), int(cell_data[1]))
    resolved = bool(entity.get("resolved", entity.get("defeated", entity.get("depleted", false))))
    collision_layer = 2
    collision_mask = 0
    input_ray_pickable = true
    _build_marker(display_name, int(entity.get("level", 1)))

func _build_marker(display_name: String, level: int) -> void:
    var mesh_instance := MeshInstance3D.new()
    var marker_mesh: PrimitiveMesh
    match kind:
        "CITY", "FORTRESS":
            var box := BoxMesh.new(); box.size = Vector3(4.2, 3.5, 4.2); marker_mesh = box
        "RESOURCE":
            var cylinder := CylinderMesh.new(); cylinder.top_radius = 1.8; cylinder.bottom_radius = 2.2; cylinder.height = 1.25; marker_mesh = cylinder
        "PVE", "MONSTER_CAMP":
            var sphere := SphereMesh.new(); sphere.radius = 1.65; sphere.height = 3.3; marker_mesh = sphere
        _:
            var prism := PrismMesh.new(); prism.size = Vector3(3.2, 3.4, 3.2); marker_mesh = prism
    base_color = _kind_color()
    var material := StandardMaterial3D.new()
    material.albedo_color = base_color.darkened(0.45) if resolved else base_color
    material.metallic = 0.12
    material.roughness = 0.64
    material.emission_enabled = true
    material.emission = base_color * (0.08 if resolved else 0.22)
    material.emission_energy_multiplier = 0.55
    mesh_instance.mesh = marker_mesh
    mesh_instance.material_override = material
    mesh_instance.position.y = 1.7
    add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new(); shape.radius = 2.6
    collision.shape = shape; collision.position.y = 1.8
    add_child(collision)

    var halo := MeshInstance3D.new()
    var halo_mesh := CylinderMesh.new(); halo_mesh.top_radius = 2.7; halo_mesh.bottom_radius = 2.7; halo_mesh.height = 0.09
    var halo_material := StandardMaterial3D.new(); halo_material.albedo_color = Color(base_color, 0.58); halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    halo.mesh = halo_mesh; halo.material_override = halo_material; halo.position.y = 0.08
    add_child(halo)

    var label := Label3D.new()
    label.text = "%s  Lv.%d" % [display_name, level] if kind != "CITY" else display_name
    label.font_size = 34; label.outline_size = 11; label.modulate = Color("fff5d9")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true; label.position.y = 5.0
    add_child(label)

func set_selected(value: bool) -> void:
    scale = Vector3.ONE * (1.16 if value else 1.0)

func _kind_color() -> Color:
    match kind:
        "CITY": return Color("f2c14e")
        "RESOURCE":
            match subtype:
                "food": return Color("d6c75f")
                "wood": return Color("5dbb74")
                "stone": return Color("9aa7b2")
                "gold": return Color("f0b642")
                _: return Color("70d6a4")
        "PVE": return Color("e86868")
        "MONSTER_CAMP": return Color("cf4f72")
        "RUINS": return Color("a78bda")
        "VILLAGE": return Color("e5aa62")
        "FORTRESS": return Color("8ba4d9")
        _: return Color("d7d7d7")

func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        selected.emit(entity_id)
    elif event is InputEventScreenTouch and event.pressed:
        selected.emit(entity_id)
