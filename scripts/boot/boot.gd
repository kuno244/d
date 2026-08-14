extends Node

func _ready() -> void:
    var registry_errors := DataRegistry.initialize()
    if not registry_errors.is_empty():
        push_error("Data/asset registry validation failed: %s" % registry_errors)
        return
    var save_data := SaveService.load_or_create()
    var save_errors := SaveService.validate(save_data)
    if not save_errors.is_empty():
        push_error("Save validation failed: %s" % save_errors)
        return
    GameState.reset_from_save(save_data)
    var err := SceneRouter.goto_frontend()
    if err != OK:
        push_error("Unable to enter frontend: %s" % error_string(err))
