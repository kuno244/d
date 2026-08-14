class_name CityPowerService
extends RefCounted

func calculate(building_instances: Array, research_progress: Dictionary, troop_inventory: Dictionary, building_definitions: Dictionary, research_definitions: Dictionary, troop_definitions: Dictionary, modifiers: ModifierService) -> int:
    var building_power := 0
    for instance_variant in building_instances:
        var instance: Dictionary = instance_variant
        if String(instance.get("state", "")) != "ACTIVE":
            continue
        var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
        var level := int(instance.get("level", 0))
        if level >= 1 and level <= definition.get("levels", []).size():
            building_power += int(definition["levels"][level - 1].get("power", 0))
    building_power = roundi(modifiers.apply(building_power, "building_power_pct"))
    var research_power := 0
    for research_id in research_progress.keys():
        var definition: Dictionary = research_definitions.get(String(research_id), {})
        research_power += int(definition.get("power_per_level", 0)) * int(research_progress[research_id])
    var troop_power := 0
    for troop_id in troop_inventory.keys():
        var definition: Dictionary = troop_definitions.get(String(troop_id), {})
        troop_power += int(definition.get("power_per_unit", 0)) * int(troop_inventory[troop_id])
    var total := building_power + research_power + troop_power
    EventHub.city_power_changed.emit(total)
    return total
