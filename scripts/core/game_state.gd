extends Node

var profile: Dictionary = {}
var resources: Dictionary = {}
var capacities: Dictionary = {}
var city_state: Dictionary = {}
var progression: Dictionary = {}
var troop_state: Dictionary = {}
var research_state: Dictionary = {}
var modifiers: Array = []
var world_state: Dictionary = {}

func reset_from_save(save_data: Dictionary) -> void:
    profile = save_data.get("profile", {}).duplicate(true)
    resources = save_data.get("resources", {}).duplicate(true)
    capacities = save_data.get("capacities", {}).duplicate(true)
    city_state = save_data.get("city_state", {}).duplicate(true)
    progression = save_data.get("progression", {}).duplicate(true)
    troop_state = save_data.get("troop_state", {}).duplicate(true)
    research_state = save_data.get("research_state", {}).duplicate(true)
    modifiers = save_data.get("modifiers", []).duplicate(true)
    world_state = save_data.get("world_state", {}).duplicate(true)

func export_state() -> Dictionary:
    return {
        "profile": profile.duplicate(true), "resources": resources.duplicate(true), "capacities": capacities.duplicate(true),
        "city_state": city_state.duplicate(true), "progression": progression.duplicate(true), "troop_state": troop_state.duplicate(true),
        "research_state": research_state.duplicate(true), "modifiers": modifiers.duplicate(true), "world_state": world_state.duplicate(true)
    }
