class_name PopulationService
extends RefCounted

var state: Dictionary
var modifiers: ModifierService
var base_current: int = 80
var base_cap: int = 200

func configure(population_state: Dictionary, modifier_service: ModifierService, progression_data: Dictionary) -> void:
    state = population_state
    modifiers = modifier_service
    var defaults: Dictionary = progression_data.get("population", {})
    base_current = int(defaults.get("starting_current", 80))
    base_cap = int(defaults.get("starting_cap", 200))

func recalculate(building_instances: Array, building_definitions: Dictionary) -> Dictionary:
    var contribution := 0
    for instance_variant in building_instances:
        var instance: Dictionary = instance_variant
        if String(instance.get("state", "")) != "ACTIVE":
            continue
        var definition: Dictionary = building_definitions.get(String(instance.get("building_id", "")), {})
        var level := int(instance.get("level", 0))
        if level < 1 or level > definition.get("levels", []).size():
            continue
        contribution += int(definition["levels"][level - 1].get("population_cap_contribution", 0))
    var cap := roundi(modifiers.apply(base_cap + contribution, "population_cap_pct"))
    var current := mini(cap, maxi(0, base_current + floori(contribution * 0.5)))
    state["current"] = current
    state["cap"] = cap
    state["available"] = maxi(0, cap - current)
    state["economy_bonus_pct"] = 0.05 if cap > 0 and float(current) / float(cap) >= 0.75 else 0.0
    EventHub.population_changed.emit(current, cap)
    return state

func training_capacity_for(base_capacity: int, population_per_unit: int) -> int:
    if base_capacity <= 0:
        return 0
    var population_limit := maxi(1, floori(float(state.get("current", base_current)) / maxf(1.0, float(population_per_unit)) * 0.5))
    return mini(base_capacity, population_limit)

func progression_requirement_met(required_population: int) -> bool:
    return int(state.get("current", base_current)) >= maxi(0, required_population)
