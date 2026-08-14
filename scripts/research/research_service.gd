class_name ResearchService
extends RefCounted

var economy: EconomyService
var modifiers: ModifierService
var research_state: Dictionary
var research_queue: Dictionary = {}

func configure(economy_service: EconomyService, modifier_service: ModifierService, state: Dictionary) -> void:
    economy = economy_service
    modifiers = modifier_service
    research_state = state
    if not research_state.has("progress") or not (research_state["progress"] is Dictionary):
        research_state["progress"] = {}
    if research_state.get("research_queue") is Dictionary:
        research_queue = research_state["research_queue"]
    else:
        research_queue = {}

func progress() -> Dictionary:
    return research_state["progress"]

func can_start(definition: Dictionary, academy_level: int, citadel_level: int) -> bool:
    if not research_queue.is_empty():
        return false
    var current := int(progress().get(String(definition.get("id", "")), 0))
    if current >= int(definition.get("max_level", 1)) or academy_level < int(definition.get("academy_requirement", 1)):
        return false
    if citadel_level < int(definition.get("citadel_requirement", 1)):
        return false
    for prerequisite_id in definition.get("prerequisites", []):
        if int(progress().get(String(prerequisite_id), 0)) < 1:
            return false
    return true

func quote(definition: Dictionary) -> Dictionary:
    var current := int(progress().get(String(definition.get("id", "")), 0))
    var cost_multiplier := pow(float(definition.get("cost_growth", 1.0)), current)
    var costs := {}
    for resource_id in definition.get("base_cost", {}).keys():
        costs[resource_id] = roundi(float(definition["base_cost"][resource_id]) * cost_multiplier / 5.0) * 5
    var speed := modifiers.percent("research_speed_pct")
    var raw_duration := float(definition.get("base_research_time_sec", 1)) * pow(float(definition.get("time_growth", 1.0)), current)
    return {"cost": costs, "duration_sec": maxi(1, ceili(raw_duration / maxf(0.01, 1.0 + speed))), "target_level": current + 1}

func start_research(definition: Dictionary, academy_level: int, citadel_level: int, now: int) -> bool:
    if not can_start(definition, academy_level, citadel_level):
        return false
    var offer := quote(definition)
    if not economy.spend_atomic(offer["cost"]):
        return false
    research_queue = {
        "research_id": String(definition.get("id", "")),
        "target_level": int(offer["target_level"]),
        "start_timestamp": now,
        "finish_timestamp": now + int(offer["duration_sec"]),
        "cost_spent": offer["cost"].duplicate(true),
        "state": "RESEARCHING"
    }
    research_state["research_queue"] = research_queue
    EventHub.research_queue_changed.emit(research_queue)
    return true

func complete_if_due(definitions_by_id: Dictionary, now: int) -> bool:
    if research_queue.is_empty() or now < int(research_queue.get("finish_timestamp", now + 1)):
        return false
    var research_id := String(research_queue.get("research_id", ""))
    if not definitions_by_id.has(research_id):
        return false
    var definition: Dictionary = definitions_by_id[research_id]
    var target_level := int(research_queue.get("target_level", 1))
    progress()[research_id] = target_level
    for effect_variant in definition.get("effects", []):
        var effect: Dictionary = effect_variant
        modifiers.set_modifier("research", research_id, String(effect.get("stat", "")), String(effect.get("mode", "PERCENT")), float(effect.get("value_per_level", 0.0)) * target_level)
    research_queue = {}
    research_state["research_queue"] = null
    EventHub.research_queue_changed.emit({})
    return true

func speed_up(seconds: int, now: int) -> int:
    if research_queue.is_empty() or seconds <= 0:
        return 0
    var before := int(research_queue.get("finish_timestamp", now))
    var after := maxi(now, before - seconds)
    research_queue["finish_timestamp"] = after
    research_state["research_queue"] = research_queue
    EventHub.research_queue_changed.emit(research_queue)
    return before - after

func remaining_time(now: int) -> int:
    return 0 if research_queue.is_empty() else maxi(0, int(research_queue.get("finish_timestamp", now)) - now)
