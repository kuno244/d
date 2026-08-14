extends Node

const FRONTEND := "res://scenes/frontend/MainMenu.tscn"
const CITY := "res://scenes/city/City.tscn"
const WORLD := "res://scenes/world/WorldMap.tscn"
const BATTLE := "res://scenes/battle/TacticalBattle.tscn"

func goto_scene(scene_path: String) -> Error:
    if not ResourceLoader.exists(scene_path):
        return ERR_FILE_NOT_FOUND
    call_deferred("_change_scene_deferred", scene_path)
    return OK

func _change_scene_deferred(scene_path: String) -> void:
    var err := get_tree().change_scene_to_file(scene_path)
    if err == OK:
        EventHub.scene_changed.emit(scene_path)
    else:
        push_error("Scene transition failed (%s): %s" % [err, scene_path])

func goto_frontend() -> Error: return goto_scene(FRONTEND)
func goto_city() -> Error: return goto_scene(CITY)
func goto_world() -> Error: return goto_scene(WORLD)
func goto_battle() -> Error: return goto_scene(BATTLE)
