class_name TroopInventory
extends RefCounted

var state: Dictionary

func configure(inventory_state: Dictionary) -> void:
    state = inventory_state

func get_count(troop_id: String) -> int:
    return int(state.get(troop_id, 0))

func add(troop_id: String, amount: int) -> int:
    var safe_amount := maxi(0, amount)
    state[troop_id] = get_count(troop_id) + safe_amount
    return get_count(troop_id)

func remove(troop_id: String, amount: int) -> bool:
    var safe_amount := maxi(0, amount)
    if get_count(troop_id) < safe_amount:
        return false
    state[troop_id] = get_count(troop_id) - safe_amount
    return true

func can_allocate(troop_id: String, amount: int) -> bool:
    return get_count(troop_id) >= maxi(0, amount)
