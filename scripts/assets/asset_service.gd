class_name AssetService
extends RefCounted

var _assets: Dictionary = {}

func _init(registry: Dictionary = {}) -> void:
    configure(registry)

func configure(registry: Dictionary) -> void:
    _assets.clear()
    for item in registry.get("assets", []):
        _assets[String(item.get("asset_id", ""))] = item

func has_asset(asset_id: String) -> bool:
    return _assets.has(asset_id)

func is_shipping_ready(asset_id: String) -> bool:
    if not _assets.has(asset_id):
        return false
    return String(_assets[asset_id].get("shipping_status", "")).begins_with("READY_")

func get_lod(asset_id: String, level: int = 0) -> String:
    if not _assets.has(asset_id) or not is_shipping_ready(asset_id):
        return ""
    var key := "LOD%d" % clampi(level, 0, 2)
    return String(_assets[asset_id].get("lods", {}).get(key, {}).get("path", ""))

func get_lod_for_distance(asset_id: String, distance: float, profile: Dictionary) -> String:
    var level := 0
    if distance > float(profile.get("lod1_max_distance", 55.0)):
        level = 2
    elif distance > float(profile.get("lod0_max_distance", 25.0)):
        level = 1
    return get_lod(asset_id, level)

func get_asset(asset_id: String) -> String:
    return get_lod(asset_id, 0)

func get_collision_definition(asset_id: String) -> Dictionary:
    if not _assets.has(asset_id):
        return {}
    return _assets[asset_id].get("collision", {}).duplicate(true)

func get_record(asset_id: String) -> Dictionary:
    if not _assets.has(asset_id):
        return {}
    return _assets[asset_id].duplicate(true)
