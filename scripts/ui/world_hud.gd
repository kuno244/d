class_name WorldHUD
extends Control

signal action_requested(action: String, entity_id: String)
signal city_requested
signal center_army_requested

@onready var food_label: Label = $Safe/TopBar/Margin/HBox/Food
@onready var wood_label: Label = $Safe/TopBar/Margin/HBox/Wood
@onready var stone_label: Label = $Safe/TopBar/Margin/HBox/Stone
@onready var gold_label: Label = $Safe/TopBar/Margin/HBox/Gold
@onready var region_label: Label = $Safe/TopBar/Margin/HBox/Region
@onready var zoom_label: Label = $Safe/TopBar/Margin/HBox/Zoom
@onready var objective_label: Label = $Safe/ObjectivePanel/Margin/Objective
@onready var selection_panel: PanelContainer = $Safe/SelectionPanel
@onready var selection_title: Label = $Safe/SelectionPanel/Margin/VBox/Title
@onready var selection_details: Label = $Safe/SelectionPanel/Margin/VBox/Details
@onready var action_button: Button = $Safe/SelectionPanel/Margin/VBox/Action
@onready var toast_label: Label = $Safe/ToastPanel/Margin/Toast

var selected_entity_id := ""
var selected_action := ""
var toast_remaining := 0.0

func _process(delta: float) -> void:
    if toast_remaining > 0.0:
        toast_remaining -= delta
        if toast_remaining <= 0.0: $Safe/ToastPanel.visible = false

func set_resources(values: Dictionary, capacities: Dictionary) -> void:
    food_label.text = "FOOD  %d/%d" % [int(values.get("food", 0)), int(capacities.get("food", 0))]
    wood_label.text = "WOOD  %d/%d" % [int(values.get("wood", 0)), int(capacities.get("wood", 0))]
    stone_label.text = "STONE  %d/%d" % [int(values.get("stone", 0)), int(capacities.get("stone", 0))]
    gold_label.text = "GOLD  %d/%d" % [int(values.get("gold", 0)), int(capacities.get("gold", 0))]

func set_location(cell: Vector2i, region: Vector2i, biome_name: String, zoom_tier: String) -> void:
    region_label.text = "%s  •  Region %d-%d  •  [%d,%d]" % [biome_name, region.x + 1, region.y + 1, cell.x, cell.y]
    zoom_label.text = zoom_tier

func set_objective(step: int) -> void:
    var objectives := [
        "Scout the realm and select a resource node",
        "Gather supplies from a world resource",
        "Explore an ancient ruin",
        "Defeat a hostile force",
        "Realm secured — expand your city and train more troops"
    ]
    objective_label.text = "CHAPTER I  •  %s" % objectives[clampi(step, 0, objectives.size() - 1)]

func show_entity(entity: Dictionary, display_name: String) -> void:
    selected_entity_id = String(entity.get("entity_id", ""))
    var kind := String(entity.get("kind", ""))
    selection_panel.visible = not selected_entity_id.is_empty()
    selection_title.text = "%s  •  Lv.%d" % [display_name, int(entity.get("level", 1))]
    selected_action = ""
    match kind:
        "CITY":
            selection_details.text = "Your capital. City production and timers continue while you explore."
            selected_action = "ENTER_CITY"; action_button.text = "ENTER CITY"
        "RESOURCE":
            selection_details.text = "%s node\nRemaining: %d / %d" % [String(entity.get("resource_type", "")).to_upper(), int(entity.get("remaining", 0)), int(entity.get("total_amount", 0))]
            selected_action = "GATHER"; action_button.text = "GATHER"
        "PVE", "MONSTER_CAMP":
            selection_details.text = "Hostile force\nCombat power: %d" % int(entity.get("combat_power", 0))
            selected_action = "ATTACK"; action_button.text = "ATTACK"
        "RUINS":
            selection_details.text = "Ancient secrets and supplies may lie within."
            selected_action = "EXPLORE"; action_button.text = "EXPLORE"
        "VILLAGE":
            selection_details.text = "A neutral settlement willing to trade supplies."
            selected_action = "TRADE"; action_button.text = "TRADE"
        "FORTRESS":
            selection_details.text = "A neutral strategic stronghold. Territory hooks are prepared."
            selected_action = "INSPECT"; action_button.text = "INSPECT"
        _:
            selection_details.text = kind.capitalize(); action_button.text = "CLOSE"
    var unavailable := bool(entity.get("depleted", entity.get("defeated", entity.get("resolved", false))))
    action_button.disabled = unavailable and kind not in ["CITY", "FORTRESS"]
    if unavailable: selection_details.text += "\nCurrently resolved — respawn timer active."

func clear_entity() -> void:
    selected_entity_id = ""; selected_action = ""; selection_panel.visible = false

func toast(message: String) -> void:
    toast_label.text = message; $Safe/ToastPanel.visible = true; toast_remaining = 3.5

func _on_action_pressed() -> void:
    if not selected_action.is_empty(): action_requested.emit(selected_action, selected_entity_id)

func _on_city_pressed() -> void:
    city_requested.emit()

func _on_army_pressed() -> void:
    center_army_requested.emit()

func _on_close_pressed() -> void:
    clear_entity()
