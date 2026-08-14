extends Node

var elapsed_seconds: float = 0.0
var simulation_scale: float = 1.0
var simulation_paused: bool = false

func _process(delta: float) -> void:
    if not simulation_paused:
        elapsed_seconds += delta * simulation_scale

func unix_time() -> int:
    return int(Time.get_unix_time_from_system())
