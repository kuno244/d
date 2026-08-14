extends Node

signal data_registry_ready
signal save_loaded
signal save_written
signal building_selected(asset_id: String)
signal building_instance_selected(instance_id: String, building_id: String)
signal building_deselected
signal building_state_changed(instance_id: String, state: String)
signal resource_changed(resource_id: String, amount: int, capacity: int)
signal construction_queue_changed(queue: Dictionary)
signal training_queue_changed(queues: Array)
signal research_queue_changed(queue: Dictionary)
signal population_changed(current: int, capacity: int)
signal city_power_changed(power: int)
signal city_loaded
signal scene_changed(scene_path: String)
