extends Control

@onready var continue_button: Button = $Center/Menu/Continue
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var graphics_preset: OptionButton = $SettingsPanel/Margin/VBox/GraphicsPreset
@onready var test_resolution: OptionButton = $SettingsPanel/Margin/VBox/TestResolution
@onready var window_mode: OptionButton = $SettingsPanel/Margin/VBox/WindowMode
@onready var camera_sensitivity: HSlider = $SettingsPanel/Margin/VBox/CameraSensitivity
@onready var ui_scale: HSlider = $SettingsPanel/Margin/VBox/UIScale

func _ready() -> void:
    continue_button.disabled = not SaveService.has_save()
    graphics_preset.select(1)
    test_resolution.select(1)
    window_mode.select(0)
    camera_sensitivity.value = 1.0
    ui_scale.value = 1.0

func _on_new_game_pressed() -> void:
    SaveService.delete_save()
    var save_data := SaveService.default_save()
    if SaveService.write_save(save_data):
        GameState.reset_from_save(save_data)
        SceneRouter.goto_city()

func _on_continue_pressed() -> void:
    var save_data := SaveService.load_or_create()
    GameState.reset_from_save(save_data)
    SceneRouter.goto_city()

func _on_settings_pressed() -> void:
    settings_panel.visible = not settings_panel.visible

func _on_quit_pressed() -> void:
    get_tree().quit()

func _on_graphics_preset_item_selected(index: int) -> void:
    # Foundation setting: maps to runtime quality choices in DEVELOPMENT 04.
    GameState.profile["graphics_preset"] = ["low", "medium", "high"][clampi(index, 0, 2)]

func _on_test_resolution_item_selected(index: int) -> void:
    var sizes := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
    get_window().size = sizes[clampi(index, 0, sizes.size() - 1)]

func _on_window_mode_item_selected(index: int) -> void:
    get_window().mode = Window.MODE_FULLSCREEN if index == 1 else Window.MODE_WINDOWED

func _on_camera_sensitivity_value_changed(value: float) -> void:
    GameState.profile["camera_sensitivity"] = value

func _on_ui_scale_value_changed(value: float) -> void:
    GameState.profile["ui_scale"] = value
    get_window().content_scale_factor = value
