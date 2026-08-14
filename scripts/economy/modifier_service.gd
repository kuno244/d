class_name ModifierService
extends RefCounted

var modifiers: Array

func configure(modifier_state: Array) -> void:
    modifiers = modifier_state

func set_modifier(source_type: String, source_id: String, stat: String, mode: String, value: float) -> void:
    for index in range(modifiers.size() - 1, -1, -1):
        var item: Dictionary = modifiers[index]
        if String(item.get("source_type", "")) == source_type and String(item.get("source_id", "")) == source_id and String(item.get("stat", "")) == stat:
            modifiers.remove_at(index)
    modifiers.append({"source_type": source_type, "source_id": source_id, "stat": stat, "mode": mode.to_upper(), "value": value})

func remove_source(source_type: String, source_id: String) -> void:
    for index in range(modifiers.size() - 1, -1, -1):
        var item: Dictionary = modifiers[index]
        if String(item.get("source_type", "")) == source_type and String(item.get("source_id", "")) == source_id:
            modifiers.remove_at(index)

func aggregate(stat: String) -> Dictionary:
    var result := {"flat": 0.0, "percent": 0.0}
    for item_variant in modifiers:
        var item: Dictionary = item_variant
        if String(item.get("stat", "")) != stat:
            continue
        if String(item.get("mode", "FLAT")).to_upper() == "PERCENT":
            result["percent"] += float(item.get("value", 0.0))
        else:
            result["flat"] += float(item.get("value", 0.0))
    return result

func apply(base_value: float, stat: String) -> float:
    var bucket := aggregate(stat)
    return (base_value + float(bucket["flat"])) * (1.0 + float(bucket["percent"]))

func percent(stat: String) -> float:
    return float(aggregate(stat)["percent"])

func flat(stat: String) -> float:
    return float(aggregate(stat)["flat"])
