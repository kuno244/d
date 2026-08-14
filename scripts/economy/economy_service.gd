class_name EconomyService
extends RefCounted

var resources: Dictionary
var capacities: Dictionary

func configure(resource_state: Dictionary, capacity_state: Dictionary) -> void:
    resources = resource_state
    capacities = capacity_state
    for resource_id in capacities.keys():
        resources[resource_id] = clampi(int(resources.get(resource_id, 0)), 0, int(capacities[resource_id]))

func get_amount(resource_id: String) -> int:
    return int(resources.get(resource_id, 0))

func get_capacity(resource_id: String) -> int:
    return int(capacities.get(resource_id, 0))

func add_resource(resource_id: String, amount: int) -> int:
    var safe_amount := maxi(0, amount)
    var current := get_amount(resource_id)
    var capacity := maxi(current, get_capacity(resource_id))
    var accepted := mini(safe_amount, maxi(0, capacity - current))
    resources[resource_id] = current + accepted
    if accepted > 0:
        EventHub.resource_changed.emit(resource_id, int(resources[resource_id]), capacity)
    return accepted

func can_afford(costs: Dictionary) -> bool:
    for resource_id in costs.keys():
        if get_amount(String(resource_id)) < maxi(0, int(costs[resource_id])):
            return false
    return true

func spend_atomic(costs: Dictionary) -> bool:
    if not can_afford(costs):
        return false
    for resource_id in costs.keys():
        var key := String(resource_id)
        resources[key] = get_amount(key) - maxi(0, int(costs[resource_id]))
    for resource_id in costs.keys():
        var key := String(resource_id)
        EventHub.resource_changed.emit(key, get_amount(key), get_capacity(key))
    return true

func set_capacity(resource_id: String, capacity: int) -> int:
    var safe_capacity := maxi(0, capacity)
    capacities[resource_id] = safe_capacity
    var overflow := maxi(0, get_amount(resource_id) - safe_capacity)
    resources[resource_id] = mini(get_amount(resource_id), safe_capacity)
    EventHub.resource_changed.emit(resource_id, get_amount(resource_id), safe_capacity)
    return overflow

func apply_reward_transaction(rewards: Dictionary) -> Dictionary:
    var accepted := {}
    for resource_id in rewards.keys():
        accepted[resource_id] = add_resource(String(resource_id), int(rewards[resource_id]))
    return accepted
