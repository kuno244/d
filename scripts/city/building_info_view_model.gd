class_name BuildingInfoViewModel
extends RefCounted

static func from_state(instance: Dictionary, definition: Dictionary, construction_queue: Dictionary = {}) -> Dictionary:
    if instance.is_empty() or definition.is_empty():
        return {}
    var level := int(instance.get("level", 0))
    var level_data: Dictionary = definition.get("levels", [])[level - 1] if level >= 1 and level <= definition.get("levels", []).size() else {}
    var next_data: Dictionary = definition.get("levels", [])[level] if level >= 0 and level < int(definition.get("max_level", 20)) else {}
    var queue_matches := not construction_queue.is_empty() and String(construction_queue.get("building_instance_id", "")) == String(instance.get("instance_id", ""))
    return {
        "instance_id": String(instance.get("instance_id", "")), "asset_id": String(instance.get("building_id", "")),
        "display_name": String(definition.get("display_name", instance.get("building_id", ""))), "role": String(definition.get("role", "")),
        "functionality": String(definition.get("functionality", "")), "level": level, "max_level": int(definition.get("max_level", 20)),
        "state": String(instance.get("state", "")), "current_stats": level_data.duplicate(true), "next_stats": next_data.duplicate(true),
        "upgrade_cost": next_data.get("cost", {}).duplicate(true), "upgrade_duration_sec": int(next_data.get("build_time_sec", 0)),
        "construction_queue": construction_queue.duplicate(true) if queue_matches else {},
        "production_stored": int(instance.get("production_stored", 0)), "can_move": String(instance.get("state", "")) == "ACTIVE"
    }
