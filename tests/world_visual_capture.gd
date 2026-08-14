extends Node

func _ready() -> void:
    call_deferred("_capture")

func _capture() -> void:
    SaveService.delete_save()
    var errors := DataRegistry.initialize()
    if not errors.is_empty():
        push_error("Capture registry failure: %s" % errors)
        get_tree().quit(1)
        return
    GameState.reset_from_save(SaveService.default_save())
    var world_scene = load("res://scenes/world/WorldMap.tscn").instantiate()
    add_child(world_scene)
    for _frame in range(18):
        await get_tree().process_frame
    if DisplayServer.get_name() == "headless":
        print("WORLD_VISUAL_CAPTURE_SKIPPED_HEADLESS")
        get_tree().quit(0)
        return
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var output_path := OS.get_environment("CROWNFRONT_CAPTURE_PATH")
    if output_path.is_empty(): output_path = "user://world_visual_capture.png"
    var error := image.save_png(output_path)
    if error != OK:
        push_error("Capture save failed: %s" % error)
        get_tree().quit(1)
        return
    print("WORLD_VISUAL_CAPTURE %dx%d %s" % [image.get_width(), image.get_height(), output_path])
    get_tree().quit(0)
