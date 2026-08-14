class_name ConstructionService
extends RefCounted

var economy: EconomyService
var modifiers: ModifierService
var city_state: Dictionary
var cancel_refund_pct: float = 0.5
var builder_slots: int = 1
var max_future_builder_slots: int = 3

func configure(economy_service: EconomyService, modifier_service: ModifierService, state: Dictionary, config: Dictionary) -> void:
    economy = economy_service
    modifiers = modifier_service
    city_state = state
    var construction_config: Dictionary = config.get("construction", {})
    cancel_refund_pct = clampf(float(construction_config.get("cancel_refund_pct", 0.5)), 0.0, 1.0)
    builder_slots = maxi(1, int(construction_config.get("initial_builder_slots", 1)))
    max_future_builder_slots = maxi(builder_slots, int(construction_config.get("max_future_builder_slots", 3)))
    if not (city_state.get("construction_queues") is Array): city_state["construction_queues"] = []
    if city_state["construction_queues"].is_empty() and city_state.get("construction_queue") is Dictionary:
        city_state["construction_queues"].append(city_state["construction_queue"])
    _sync_active_alias()

func active_queues() -> Array:
    return city_state.get("construction_queues", [])

func has_active_queue() -> bool:
    return not active_queues().is_empty()

func queue_slots_full() -> bool:
    return active_queues().size() >= builder_slots

func get_queue() -> Dictionary:
    return active_queues()[0] if not active_queues().is_empty() else {}

func _sync_active_alias() -> void:
    city_state["construction_queue"] = active_queues()[0] if not active_queues().is_empty() else null

func prerequisites_met(definition: Dictionary, building_levels: Dictionary, citadel_level: int) -> bool:
    for requirement_variant in definition.get("prerequisites", []):
        var requirement: Dictionary = requirement_variant
        var required_id := String(requirement.get("building_id", ""))
        var required_level := int(requirement.get("level", 1))
        var actual_level := citadel_level if required_id == "building_royal_citadel" else int(building_levels.get(required_id, 0))
        if actual_level < required_level:
            return false
    return true

func can_start_build(definition: Dictionary, citadel_level: int, population: int, building_levels: Dictionary = {}) -> bool:
    if queue_slots_full():
        return false
    if int(definition.get("unlock_citadel_level", 1)) > citadel_level or not prerequisites_met(definition, building_levels, citadel_level):
        return false
    var levels: Array = definition.get("levels", [])
    if levels.is_empty():
        return false
    return int(levels[0].get("population_required", 0)) <= population

func can_upgrade(definition: Dictionary, instance: Dictionary, citadel_level: int, population: int, building_levels: Dictionary = {}) -> bool:
    if queue_slots_full() or String(instance.get("state", "")) != "ACTIVE" or not prerequisites_met(definition, building_levels, citadel_level):
        return false
    var current_level := int(instance.get("level", 0))
    var target_level := current_level + 1
    if target_level > int(definition.get("max_level", 20)):
        return false
    var level_data: Dictionary = definition.get("levels", [])[target_level - 1]
    if String(definition.get("id", "")) != "building_royal_citadel" and int(level_data.get("citadel_required_level", target_level)) > citadel_level:
        return false
    return int(level_data.get("population_required", 0)) <= population

func start_build(definition: Dictionary, instance: Dictionary, now: int, citadel_level: int, population: int, building_levels: Dictionary = {}) -> bool:
    if int(instance.get("level", 0)) != 0 or not can_start_build(definition, citadel_level, population, building_levels):
        return false
    return _start(definition, instance, 1, now)

func start_upgrade(definition: Dictionary, instance: Dictionary, now: int, citadel_level: int, population: int, building_levels: Dictionary = {}) -> bool:
    if not can_upgrade(definition, instance, citadel_level, population, building_levels):
        return false
    return _start(definition, instance, int(instance.get("level", 0)) + 1, now)

func _start(definition: Dictionary, instance: Dictionary, target_level: int, now: int) -> bool:
    var level_data: Dictionary = definition.get("levels", [])[target_level - 1]
    var costs: Dictionary = level_data.get("cost", {})
    if not economy.spend_atomic(costs):
        return false
    var speed := modifiers.percent("construction_speed_pct")
    var duration := maxi(1, ceili(float(level_data.get("build_time_sec", 1)) / maxf(0.01, 1.0 + speed)))
    var previous_state := String(instance.get("state", "PLACING"))
    var previous_level := int(instance.get("level", 0))
    instance["state"] = "CONSTRUCTING" if previous_level == 0 else "UPGRADING"
    var queue := {
        "builder_slot": active_queues().size(),
        "type": "BUILD" if previous_level == 0 else "UPGRADE",
        "building_instance_id": String(instance.get("instance_id", "")),
        "building_id": String(definition.get("id", "")),
        "previous_state": previous_state,
        "previous_level": previous_level,
        "target_level": target_level,
        "start_timestamp": now,
        "finish_timestamp": now + duration,
        "cost_spent": costs.duplicate(true),
        "state": "ACTIVE_QUEUE"
    }
    active_queues().append(queue)
    _sync_active_alias()
    EventHub.construction_queue_changed.emit(get_queue())
    return true

func complete_if_due(instances_by_id: Dictionary, now: int) -> bool:
    if not has_active_queue():
        return false
    var queue := get_queue()
    if now < int(queue.get("finish_timestamp", now + 1)):
        return false
    var instance_id := String(queue.get("building_instance_id", ""))
    if not instances_by_id.has(instance_id):
        return false
    var instance: Dictionary = instances_by_id[instance_id]
    instance["level"] = int(queue.get("target_level", instance.get("level", 0)))
    instance["state"] = "ACTIVE"
    active_queues().remove_at(0)
    _sync_active_alias()
    EventHub.building_state_changed.emit(instance_id, "ACTIVE")
    EventHub.construction_queue_changed.emit(get_queue())
    return true

func cancel(instances_by_id: Dictionary, now: int) -> Dictionary:
    if not has_active_queue():
        return {}
    var queue := get_queue()
    var instance_id := String(queue.get("building_instance_id", ""))
    if not instances_by_id.has(instance_id):
        return {}
    var instance: Dictionary = instances_by_id[instance_id]
    for resource_id in queue.get("cost_spent", {}).keys():
        economy.add_resource(String(resource_id), floori(int(queue["cost_spent"][resource_id]) * cancel_refund_pct))
    var was_new_build := int(queue.get("previous_level", 0)) == 0
    instance["level"] = int(queue.get("previous_level", 0))
    instance["state"] = String(queue.get("previous_state", "PLACING"))
    if not was_new_build:
        instance["last_production_timestamp"] = now
    active_queues().remove_at(0)
    _sync_active_alias()
    EventHub.construction_queue_changed.emit(get_queue())
    return {"cancelled": true, "remove_instance": was_new_build, "building_instance_id": instance_id}

func speed_up(seconds: int, now: int) -> int:
    if not has_active_queue() or seconds <= 0:
        return 0
    var queue := get_queue()
    var before := int(queue.get("finish_timestamp", now))
    var after := maxi(now, before - seconds)
    queue["finish_timestamp"] = after
    _sync_active_alias()
    EventHub.construction_queue_changed.emit(queue)
    return before - after

func remaining_time(now: int) -> int:
    if not has_active_queue():
        return 0
    return maxi(0, int(get_queue().get("finish_timestamp", now)) - now)
