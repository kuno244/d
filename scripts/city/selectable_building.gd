class_name SelectableBuilding
extends StaticBody3D

@export var asset_id: String = ""
@export var display_name: String = "Building"
var selected := false

func select() -> void:
    selected = true
    EventHub.building_selected.emit(asset_id)

func deselect() -> void:
    if selected:
        selected = false
        EventHub.building_deselected.emit()
