class_name CityHUD
extends Control

var city: Node
var selected_instance_id := ""

@onready var food_label: Label = $SafeArea/TopBar/Margin/Resources/Food
@onready var wood_label: Label = $SafeArea/TopBar/Margin/Resources/Wood
@onready var stone_label: Label = $SafeArea/TopBar/Margin/Resources/Stone
@onready var gold_label: Label = $SafeArea/TopBar/Margin/Resources/Gold
@onready var power_label: Label = $SafeArea/TopBar/Margin/Resources/Power
@onready var population_label: Label = $SafeArea/TopBar/Margin/Resources/Population
@onready var build_panel: PanelContainer = $SafeArea/BuildPanel
@onready var build_list: VBoxContainer = $SafeArea/BuildPanel/Margin/VBox/Scroll/Items
@onready var building_panel: PanelContainer = $SafeArea/BuildingPanel
@onready var building_title: Label = $SafeArea/BuildingPanel/Margin/VBox/Title
@onready var building_state: Label = $SafeArea/BuildingPanel/Margin/VBox/State
@onready var building_function: Label = $SafeArea/BuildingPanel/Margin/VBox/Function
@onready var building_upgrade_preview: Label = $SafeArea/BuildingPanel/Margin/VBox/UpgradePreview
@onready var upgrade_button: Button = $SafeArea/BuildingPanel/Margin/VBox/Upgrade
@onready var move_button: Button = $SafeArea/BuildingPanel/Margin/VBox/Move
@onready var collect_button: Button = $SafeArea/BuildingPanel/Margin/VBox/Collect
@onready var construction_panel: PanelContainer = $SafeArea/ConstructionPanel
@onready var construction_text: Label = $SafeArea/ConstructionPanel/Margin/VBox/Construction
@onready var construction_progress: ProgressBar = $SafeArea/ConstructionPanel/Margin/VBox/Progress
@onready var placement_panel: PanelContainer = $SafeArea/PlacementPanel
@onready var placement_status: Label = $SafeArea/PlacementPanel/Margin/HBox/PlacementStatus
@onready var placement_confirm: Button = $SafeArea/PlacementPanel/Margin/HBox/Confirm
@onready var training_panel: PanelContainer = $SafeArea/TrainingPanel
@onready var training_list: VBoxContainer = $SafeArea/TrainingPanel/Margin/VBox/Scroll/Items
@onready var training_amount: SpinBox = $SafeArea/TrainingPanel/Margin/VBox/TrainingAmount
@onready var training_queue_label: Label = $SafeArea/TrainingPanel/Margin/VBox/QueueStatus
@onready var research_panel: PanelContainer = $SafeArea/ResearchPanel
@onready var research_list: VBoxContainer = $SafeArea/ResearchPanel/Margin/VBox/Scroll/Items
@onready var research_queue_label: Label = $SafeArea/ResearchPanel/Margin/VBox/QueueStatus
@onready var hero_panel: PanelContainer = $SafeArea/HeroPanel

func _ready() -> void:
    _populate_build_menu()
    _populate_training()
    _populate_research()

func bind_city(city_controller: Node) -> void:
    city = city_controller
    refresh_all()
    refresh_placement_mode(city.build_mode.mode)

func refresh_all() -> void:
    if city == null:
        return
    refresh_resources(GameState.resources, GameState.capacities)
    power_label.text = "Power  %d" % int(GameState.city_state.get("city_power", 0))
    var pop: Dictionary = GameState.city_state.get("population", {})
    population_label.text = "Pop  %d/%d" % [int(pop.get("current", 0)), int(pop.get("cap", 0))]
    refresh_construction()
    _populate_training()
    _populate_research()
    if not selected_instance_id.is_empty():
        show_building(city.get_building_view_model(selected_instance_id))

func refresh_resources(resources: Dictionary, capacities: Dictionary) -> void:
    food_label.text = "Food  %d/%d" % [int(resources.get("food", 0)), int(capacities.get("food", 0))]
    wood_label.text = "Wood  %d/%d" % [int(resources.get("wood", 0)), int(capacities.get("wood", 0))]
    stone_label.text = "Stone  %d/%d" % [int(resources.get("stone", 0)), int(capacities.get("stone", 0))]
    gold_label.text = "Gold  %d/%d" % [int(resources.get("gold", 0)), int(capacities.get("gold", 0))]

func show_building(view_model: Dictionary) -> void:
    if view_model.is_empty():
        building_panel.visible = false
        selected_instance_id = ""
        return
    selected_instance_id = String(view_model.get("instance_id", ""))
    building_panel.visible = true
    building_title.text = "%s  Lv.%d/%d" % [String(view_model.get("display_name", "Building")), int(view_model.get("level", 0)), int(view_model.get("max_level", 20))]
    building_state.text = "State: %s" % String(view_model.get("state", ""))
    building_function.text = "Function: %s" % String(view_model.get("functionality", ""))
    var current_stats: Dictionary = view_model.get("current_stats", {})
    var next_stats: Dictionary = view_model.get("next_stats", {})
    if next_stats.is_empty():
        building_upgrade_preview.text = "MAX LEVEL"
    else:
        var cost: Dictionary = view_model.get("upgrade_cost", {})
        var requirements: Array = view_model.get("requirements", [])
        var requirement_text := "None" if requirements.is_empty() else ", ".join(requirements)
        var status := String(view_model.get("upgrade_status", ""))
        building_upgrade_preview.text = "Next Lv.%d • %s • %s\n%s\nRequirements: %s\nStatus: %s" % [
            int(view_model.get("level", 0)) + 1,
            _cost_text(cost),
            _format_time(int(view_model.get("upgrade_duration_sec", 0))),
            _stat_delta_text(current_stats, next_stats),
            requirement_text,
            status
        ]
    upgrade_button.disabled = not bool(view_model.get("upgrade_available", false))
    move_button.disabled = not bool(view_model.get("can_move", false))
    collect_button.disabled = not bool(view_model.get("can_collect", false))

func refresh_construction() -> void:
    var queue = GameState.city_state.get("construction_queue")
    construction_panel.visible = queue is Dictionary
    if queue is Dictionary:
        var now := GameClock.unix_time()
        var start := int(queue.get("start_timestamp", now))
        var finish := int(queue.get("finish_timestamp", now))
        var remaining := maxi(0, finish - now)
        construction_text.text = "Construction  → Lv.%d   %s" % [int(queue.get("target_level", 0)), _format_time(remaining)]
        construction_progress.max_value = maxf(1.0, float(finish - start))
        construction_progress.value = clampf(float(now - start), 0.0, construction_progress.max_value)

func refresh_placement_mode(mode: String) -> void:
    if placement_panel == null:
        return
    placement_panel.visible = mode != "NONE"
    if mode == "NONE":
        return
    placement_status.text = "Placement: %s" % mode.replace("_", " ").capitalize()
    if city != null:
        set_placement_validity(bool(city.build_mode.preview_valid))

func set_placement_validity(valid: bool) -> void:
    if placement_panel == null or not placement_panel.visible:
        return
    placement_confirm.disabled = not valid
    placement_status.text = "%s • %s" % [placement_status.text.split(" • ")[0], "VALID" if valid else "INVALID"]

func _on_placement_confirm_pressed() -> void:
    if city != null:
        city.confirm_placement()

func _on_placement_cancel_pressed() -> void:
    if city != null:
        city.cancel_placement()

func _on_placement_rotate_pressed() -> void:
    if city != null:
        city.rotate_placement()

func open_build_menu() -> void:
    _populate_build_menu()
    _show_exclusive(build_panel)

func open_research() -> void:
    _populate_research()
    _show_exclusive(research_panel)

func open_troops() -> void:
    _populate_training()
    _show_exclusive(training_panel)

func open_heroes() -> void:
    _show_exclusive(hero_panel)

func _on_world_pressed() -> void:
    if city != null:
        city.goto_world_hook()

func _on_upgrade_pressed() -> void:
    if city != null and not selected_instance_id.is_empty(): city.request_upgrade(selected_instance_id)

func _on_move_pressed() -> void:
    if city != null and not selected_instance_id.is_empty(): city.request_move(selected_instance_id)

func _on_info_pressed() -> void:
    if city != null and not selected_instance_id.is_empty(): show_building(city.get_building_view_model(selected_instance_id))

func _on_collect_pressed() -> void:
    if city != null and not selected_instance_id.is_empty(): city.request_collect(selected_instance_id)

func _on_cancel_construction_pressed() -> void:
    if city != null: city.request_cancel_construction()

func _on_speedup_hook_pressed() -> void:
    if city != null: city.request_construction_speedup(60)

func _populate_build_menu() -> void:
    if build_list == null: return
    for child in build_list.get_children(): child.queue_free()
    for definition_variant in DataRegistry.get_items("buildings"):
        var definition: Dictionary = definition_variant
        var button := Button.new()
        button.custom_minimum_size = Vector2(220, 52)
        var first: Dictionary = definition.get("levels", [])[0]
        button.text = "%s • %dx%d • %s • %s" % [String(definition.get("display_name", "")), int(definition.get("footprint", [1,1])[0]), int(definition.get("footprint", [1,1])[1]), _cost_text(first.get("cost", {})), _format_time(int(first.get("build_time_sec", 0)))]
        var building_id := String(definition.get("id", ""))
        if city != null:
            var status: Dictionary = city.get_build_status(building_id)
            button.disabled = not bool(status.get("available", false))
            button.text += " • %d/%d" % [int(status.get("count", 0)), int(status.get("max_count", 0))]
            if button.disabled: button.text += " • LOCKED/BUSY"
        button.pressed.connect(func(): _request_build(building_id))
        build_list.add_child(button)
    var decoration := Button.new(); decoration.custom_minimum_size = Vector2(220, 52); decoration.text = "Bush Cluster • Decoration"
    decoration.pressed.connect(func(): _request_decoration("decoration_bush_cluster")); build_list.add_child(decoration)
    if city != null:
        var header := Label.new()
        header.text = "Placed Decorations"
        header.add_theme_font_size_override("font_size", 18)
        build_list.add_child(header)
        for state_variant in GameState.city_state.get("decorations", []):
            if not (state_variant is Dictionary):
                continue
            var state: Dictionary = state_variant
            var decoration_id := String(state.get("instance_id", ""))
            var row := HBoxContainer.new()
            var label := Label.new()
            label.text = "Bush Cluster"
            label.custom_minimum_size = Vector2(120, 48)
            var move_button := Button.new()
            move_button.text = "Move"
            move_button.custom_minimum_size = Vector2(90, 48)
            move_button.pressed.connect(func(): _request_move_decoration(decoration_id))
            var remove_button := Button.new()
            remove_button.text = "Remove"
            remove_button.custom_minimum_size = Vector2(90, 48)
            remove_button.pressed.connect(func(): _request_remove_decoration(decoration_id))
            row.add_child(label)
            row.add_child(move_button)
            row.add_child(remove_button)
            build_list.add_child(row)

func _populate_training() -> void:
    if training_list == null: return
    for child in training_list.get_children(): child.queue_free()
    var inventory: Dictionary = GameState.troop_state.get("inventory", {})
    var queues: Array = GameState.troop_state.get("training_queues", [])
    training_queue_label.text = "Queue: empty" if queues.is_empty() else "Queue: %s ×%d • %s" % [String(queues[0].get("troop_id", "")), int(queues[0].get("amount", 0)), _format_time(maxi(0, int(queues[0].get("finish_timestamp", 0)) - GameClock.unix_time()))]
    for definition_variant in DataRegistry.get_items("troops"):
        var definition: Dictionary = definition_variant
        var button := Button.new(); button.custom_minimum_size = Vector2(240, 52)
        var troop_id := String(definition.get("id", ""))
        button.text = "%s • Owned %d • %s ea • %ds ea" % [String(definition.get("display_name", "")), int(inventory.get(troop_id, 0)), _cost_text(definition.get("base_training_cost", {})), int(definition.get("base_training_time_sec", 0))]
        if city != null:
            var status: Dictionary = city.get_training_status(troop_id, int(training_amount.value))
            button.disabled = not bool(status.get("available", false))
            if button.disabled: button.text += " • LOCKED/BUSY"
        button.pressed.connect(func(): _request_training(troop_id))
        training_list.add_child(button)

func _populate_research() -> void:
    if research_list == null: return
    for child in research_list.get_children(): child.queue_free()
    var current_branch := ""
    var progress: Dictionary = GameState.research_state.get("progress", {})
    var queue = GameState.research_state.get("research_queue")
    research_queue_label.text = "Current research: none" if not (queue is Dictionary) else "Current research: %s • %s" % [String(queue.get("research_id", "")), _format_time(maxi(0, int(queue.get("finish_timestamp", 0)) - GameClock.unix_time()))]
    for definition_variant in DataRegistry.get_items("research"):
        var definition: Dictionary = definition_variant
        var branch := String(definition.get("branch", ""))
        if branch != current_branch:
            current_branch = branch
            var header := Label.new(); header.text = branch.to_upper(); header.add_theme_font_size_override("font_size", 18); research_list.add_child(header)
        var button := Button.new(); button.custom_minimum_size = Vector2(260, 52)
        var research_id := String(definition.get("id", ""))
        button.text = "%s • Lv.%d/%d" % [String(definition.get("display_name", "")), int(progress.get(research_id,0)), int(definition.get("max_level",5))]
        if city != null:
            var status: Dictionary = city.get_research_status(research_id)
            button.disabled = not bool(status.get("available", false))
            button.text += " • %s • %s" % [_cost_text(status.get("cost", definition.get("base_cost", {}))), _format_time(int(status.get("duration_sec", definition.get("base_research_time_sec", 0))))]
            if button.disabled: button.text += " • LOCKED/BUSY"
        button.pressed.connect(func(): _request_research(research_id))
        research_list.add_child(button)

func _request_build(building_id: String) -> void:
    if city != null and city.request_build(building_id): build_panel.visible = false

func _request_decoration(asset_id: String) -> void:
    if city != null and city.request_decoration(asset_id): build_panel.visible = false

func _request_move_decoration(decoration_id: String) -> void:
    if city != null and city.request_move_decoration(decoration_id):
        build_panel.visible = false

func _request_remove_decoration(decoration_id: String) -> void:
    if city != null and city.request_remove_decoration(decoration_id):
        _populate_build_menu()

func _request_training(troop_id: String) -> void:
    if city != null: city.request_train(troop_id, int(training_amount.value))

func _request_research(research_id: String) -> void:
    if city != null: city.request_research(research_id)

func _show_exclusive(panel: Control) -> void:
    for candidate in [build_panel, training_panel, research_panel, hero_panel]: candidate.visible = candidate == panel and not candidate.visible

func _cost_text(cost: Dictionary) -> String:
    return "F%d W%d S%d G%d" % [int(cost.get("food", 0)), int(cost.get("wood", 0)), int(cost.get("stone", 0)), int(cost.get("gold", 0))]

func _format_time(seconds: int) -> String:
    var safe_seconds := maxi(0, seconds)
    var h := int(safe_seconds / 3600)
    var m := int((safe_seconds % 3600) / 60)
    var s := safe_seconds % 60
    return "%02d:%02d:%02d" % [h, m, s]

func _stat_delta_text(current_stats: Dictionary, next_stats: Dictionary) -> String:
    var labels := {
        "production_per_hour": "Production/h",
        "local_production_cap": "Local cap",
        "storage_contribution": "Storage",
        "population_cap_contribution": "Population cap",
        "training_capacity": "Training cap",
        "training_speed_pct": "Training speed %",
        "research_speed_pct": "Research speed %",
        "power": "Power"
    }
    var changes: Array[String] = []
    for stat in labels.keys():
        if not next_stats.has(stat):
            continue
        var before := float(current_stats.get(stat, 0))
        var after := float(next_stats.get(stat, 0))
        if is_equal_approx(before, after):
            continue
        changes.append("%s %s→%s" % [String(labels[stat]), _number_text(before), _number_text(after)])
    return "Changes: none" if changes.is_empty() else "Changes: " + ", ".join(changes)

func _number_text(value: float) -> String:
    if is_equal_approx(value, round(value)):
        return str(int(round(value)))
    return "%.1f" % value
