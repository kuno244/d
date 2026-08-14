class_name TrainingService
extends RefCounted

var economy: EconomyService
var modifiers: ModifierService
var population: PopulationService
var inventory: TroopInventory
var troop_state: Dictionary
var training_queue: Array
var cancel_refund_pct: float = 0.5

func configure(economy_service: EconomyService, modifier_service: ModifierService, population_service: PopulationService, inventory_service: TroopInventory, state: Dictionary) -> void:
    economy = economy_service
    modifiers = modifier_service
    population = population_service
    inventory = inventory_service
    troop_state = state
    if not troop_state.has("training_queues") or not (troop_state["training_queues"] is Array):
        troop_state["training_queues"] = []
    training_queue = troop_state["training_queues"]

func quote(troop_definition: Dictionary, amount: int, building_level_data: Dictionary) -> Dictionary:
    var safe_amount := maxi(0, amount)
    var costs := {}
    for resource_id in troop_definition.get("base_training_cost", {}).keys():
        costs[resource_id] = int(troop_definition["base_training_cost"][resource_id]) * safe_amount
    var speed := float(building_level_data.get("training_speed_pct", 0.0)) + modifiers.percent("training_speed_pct")
    var duration := 0 if safe_amount == 0 else maxi(1, ceili(float(troop_definition.get("base_training_time_sec", 1)) * safe_amount / maxf(0.01, 1.0 + speed)))
    return {"cost": costs, "duration_sec": duration}

func start_training(troop_definition: Dictionary, building_instance: Dictionary, building_definition: Dictionary, amount: int, citadel_level: int, now: int) -> bool:
    if amount <= 0 or String(building_instance.get("state", "")) != "ACTIVE":
        return false
    if String(troop_definition.get("training_building_id", "")) != String(building_instance.get("building_id", "")):
        return false
    var building_level := int(building_instance.get("level", 0))
    if building_level < int(troop_definition.get("unlock_building_level", 1)) or citadel_level < int(troop_definition.get("unlock_citadel_level", 1)):
        return false
    for queue_variant in training_queue:
        var existing: Dictionary = queue_variant
        if String(existing.get("building_instance_id", "")) == String(building_instance.get("instance_id", "")) and String(existing.get("state", "")) == "TRAINING":
            return false
    var level_data: Dictionary = building_definition.get("levels", [])[building_level - 1]
    var base_capacity := int(level_data.get("training_capacity", 0))
    var effective_capacity := population.training_capacity_for(base_capacity, int(troop_definition.get("population_per_unit", 1)))
    if amount > effective_capacity:
        return false
    var offer := quote(troop_definition, amount, level_data)
    if not economy.spend_atomic(offer["cost"]):
        return false
    var queue_id := "training_%s_%d" % [String(building_instance.get("instance_id", "")), now]
    training_queue.append({
        "queue_id": queue_id,
        "building_instance_id": String(building_instance.get("instance_id", "")),
        "troop_id": String(troop_definition.get("id", "")),
        "amount": amount,
        "start_timestamp": now,
        "finish_timestamp": now + int(offer["duration_sec"]),
        "cost_spent": offer["cost"].duplicate(true),
        "state": "TRAINING"
    })
    EventHub.training_queue_changed.emit(training_queue)
    return true

func complete_due(now: int) -> int:
    var completed := 0
    for queue_variant in training_queue:
        var queue: Dictionary = queue_variant
        if String(queue.get("state", "")) != "TRAINING" or now < int(queue.get("finish_timestamp", now + 1)):
            continue
        inventory.add(String(queue.get("troop_id", "")), int(queue.get("amount", 0)))
        queue["state"] = "COMPLETE"
        completed += 1
    for index in range(training_queue.size() - 1, -1, -1):
        if String(training_queue[index].get("state", "")) == "COMPLETE":
            training_queue.remove_at(index)
    if completed > 0:
        EventHub.training_queue_changed.emit(training_queue)
    return completed

func speed_up(queue_id: String, seconds: int, now: int) -> int:
    if seconds <= 0:
        return 0
    for queue_variant in training_queue:
        var queue: Dictionary = queue_variant
        if String(queue.get("queue_id", "")) != queue_id or String(queue.get("state", "")) != "TRAINING":
            continue
        var before := int(queue.get("finish_timestamp", now))
        var after := maxi(now, before - seconds)
        queue["finish_timestamp"] = after
        EventHub.training_queue_changed.emit(training_queue)
        return before - after
    return 0

func cancel(queue_id: String) -> bool:
    for index in range(training_queue.size()):
        var queue: Dictionary = training_queue[index]
        if String(queue.get("queue_id", "")) != queue_id or String(queue.get("state", "")) != "TRAINING":
            continue
        for resource_id in queue.get("cost_spent", {}).keys():
            economy.add_resource(String(resource_id), floori(int(queue["cost_spent"][resource_id]) * cancel_refund_pct))
        training_queue.remove_at(index)
        EventHub.training_queue_changed.emit(training_queue)
        return true
    return false
