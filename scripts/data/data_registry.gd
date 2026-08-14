extends Node

const AssetServiceClass = preload("res://scripts/assets/asset_service.gd")
const DATA_FILES := {
    "resources": "res://data/resources/resources.json",
    "buildings": "res://data/buildings/buildings.json",
    "troops": "res://data/troops/troops.json",
    "heroes": "res://data/heroes/heroes.json",
    "pve": "res://data/pve/pve.json",
    "research": "res://data/research/research.json",
    "progression": "res://data/progression/progression.json",
    "city": "res://data/city/city_config.json",
    "economy": "res://data/economy/economy.json",
    "world": "res://data/world/world.json",
}
const ASSET_REGISTRY_PATH := "res://registry/asset_registry.json"

var data: Dictionary = {}
var asset_registry: Dictionary = {}
var asset_service: AssetService
var initialized := false

func initialize() -> Array[String]:
    var errors: Array[String] = []
    data.clear()
    for key in DATA_FILES:
        var loaded = _load_json(DATA_FILES[key])
        if loaded == null:
            errors.append("Failed to load %s" % DATA_FILES[key])
        else:
            data[key] = loaded
    var registry = _load_json(ASSET_REGISTRY_PATH)
    if registry == null:
        errors.append("Failed to load asset registry")
    else:
        asset_registry = registry
        asset_service = AssetServiceClass.new(asset_registry)
    errors.append_array(validate())
    initialized = errors.is_empty()
    if initialized:
        EventHub.data_registry_ready.emit()
    return errors

func validate() -> Array[String]:
    var errors: Array[String] = []
    if asset_registry.is_empty():
        errors.append("Asset registry is empty")
        return errors
    var seen := {}
    for item in asset_registry.get("assets", []):
        var aid := String(item.get("asset_id", ""))
        if aid.is_empty():
            errors.append("Asset with empty ID")
        elif seen.has(aid):
            errors.append("Duplicate asset ID: %s" % aid)
        else:
            seen[aid] = true
    for dataset_name in ["buildings", "troops", "heroes", "pve"]:
        for item in data.get(dataset_name, {}).get("items", []):
            var aid := String(item.get("asset_id", ""))
            if not seen.has(aid):
                errors.append("%s references missing asset: %s" % [dataset_name, aid])
    return errors

func get_items(dataset_name: String) -> Array:
    return data.get(dataset_name, {}).get("items", [])

func get_definition(dataset_name: String, definition_id: String) -> Dictionary:
    for item in get_items(dataset_name):
        if String(item.get("id", item.get("asset_id", ""))) == definition_id:
            return item
    return {}

func _load_json(path: String):
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed
