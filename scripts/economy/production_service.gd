class_name ProductionService
extends RefCounted

var economy: EconomyService
var modifiers: ModifierService
var offline_cap_sec: int = 36000
var max_timestamp_delta_sec: int = 604800

func configure(economy_service: EconomyService, modifier_service: ModifierService, city_config: Dictionary) -> void:
    economy = economy_service
    modifiers = modifier_service
    var offline: Dictionary = city_config.get("offline", {})
    offline_cap_sec = maxi(0, int(offline.get("base_cap_sec", 36000)))
    max_timestamp_delta_sec = maxi(offline_cap_sec, int(offline.get("max_timestamp_delta_sec", 604800)))

func sanitized_elapsed(last_timestamp: int, now: int) -> int:
    if now < last_timestamp:
        return 0
    return mini(now - last_timestamp, mini(offline_cap_sec, max_timestamp_delta_sec))

func accrue(instance: Dictionary, definition: Dictionary, now: int) -> int:
    if String(instance.get("state", "")) != "ACTIVE" or not definition.has("production"):
        return int(instance.get("production_stored", 0))
    var level := clampi(int(instance.get("level", 1)), 1, int(definition.get("max_level", 20)))
    var level_data: Dictionary = definition.get("levels", [])[level - 1]
    var resource_id := String(definition.get("production", {}).get("resource", ""))
    var last_timestamp := int(instance.get("last_production_timestamp", now))
    if now < last_timestamp:
        return int(instance.get("production_stored", 0))
    var elapsed := sanitized_elapsed(last_timestamp, now)
    var rate := float(level_data.get("production_per_hour", 0))
    rate = modifiers.apply(rate, "%s_production_pct" % resource_id)
    var produced := maxi(0, floori(rate * elapsed / 3600.0))
    var local_cap := maxi(0, int(level_data.get("local_production_cap", 0)))
    instance["production_stored"] = mini(local_cap, maxi(0, int(instance.get("production_stored", 0))) + produced)
    instance["last_production_timestamp"] = now
    return int(instance["production_stored"])

func claim(instance: Dictionary, definition: Dictionary, now: int) -> int:
    accrue(instance, definition, now)
    var resource_id := String(definition.get("production", {}).get("resource", ""))
    var stored := maxi(0, int(instance.get("production_stored", 0)))
    var accepted := economy.add_resource(resource_id, stored)
    instance["production_stored"] = stored - accepted
    return accepted
