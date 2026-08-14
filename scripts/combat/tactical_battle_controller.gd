class_name TacticalBattleController
extends Control

@onready var enemy_name: Label = $Safe/EnemyCard/Margin/VBox/EnemyName
@onready var enemy_power: Label = $Safe/EnemyCard/Margin/VBox/EnemyPower
@onready var enemy_health: ProgressBar = $Safe/EnemyCard/Margin/VBox/EnemyHealth
@onready var army_name: Label = $Safe/ArmyCard/Margin/VBox/ArmyName
@onready var army_power: Label = $Safe/ArmyCard/Margin/VBox/ArmyPower
@onready var army_health: ProgressBar = $Safe/ArmyCard/Margin/VBox/ArmyHealth
@onready var event_label: Label = $Safe/EventPanel/Margin/Event
@onready var round_label: Label = $Safe/Header/Round
@onready var strike_button: Button = $Safe/Commands/CommanderStrike
@onready var shield_button: Button = $Safe/Commands/ShieldWall
@onready var auto_button: Button = $Safe/Commands/AutoBattle
@onready var retreat_button: Button = $Safe/Commands/Retreat
@onready var result_panel: PanelContainer = $Safe/ResultPanel
@onready var result_title: Label = $Safe/ResultPanel/Margin/VBox/Title
@onready var result_details: Label = $Safe/ResultPanel/Margin/VBox/Details
@onready var battle_timer: Timer = $BattleTimer

var battle_service := BattleService.new()
var world_service := WorldService.new()
var auto_battle := false
var finished := false

func _ready() -> void:
    if not DataRegistry.initialized: DataRegistry.initialize()
    var world_config: Dictionary = DataRegistry.data.get("world", {}).get("world", {})
    world_service.configure(GameState.world_state, world_config, GameState.resources, GameState.capacities)
    var pending = GameState.world_state.get("pending_battle")
    if not (pending is Dictionary):
        _show_invalid_battle()
        return
    var entity := world_service.get_entity(String(pending.get("entity_id", "")))
    var army := world_service.get_army(String(pending.get("army_id", "army_player_001")))
    if entity.is_empty() or army.is_empty():
        _show_invalid_battle()
        return
    var troop_power: Dictionary = {}
    for troop_variant in DataRegistry.get_items("troops"):
        var troop: Dictionary = troop_variant
        troop_power[String(troop.get("id", ""))] = int(troop.get("power_per_unit", 1))
    var snapshot := battle_service.start(army.get("troops", {}), troop_power, int(pending.get("enemy_power", 100)), int(pending.get("seed", 1)))
    enemy_name.text = _enemy_display_name(entity)
    army_name.text = String(army.get("display_name", "Crown Vanguard"))
    enemy_health.max_value = int(snapshot["enemy_max_hp"]); army_health.max_value = int(snapshot["player_max_hp"])
    _refresh(snapshot)
    battle_timer.start()

func _on_battle_timer_timeout() -> void:
    if auto_battle and not finished: _perform_step("STANDARD")

func _on_commander_strike_pressed() -> void:
    _perform_step("COMMANDER_STRIKE")

func _on_shield_wall_pressed() -> void:
    _perform_step("SHIELD_WALL")

func _on_auto_battle_pressed() -> void:
    auto_battle = not auto_battle
    auto_button.text = "PAUSE" if auto_battle else "AUTO BATTLE"

func _on_retreat_pressed() -> void:
    if finished: return
    battle_service.retreat()
    finish_battle(battle_service.result())

func _on_return_pressed() -> void:
    SceneRouter.goto_world()

func _perform_step(action: String) -> void:
    if finished: return
    var snapshot := battle_service.step(action)
    _refresh(snapshot)
    if bool(snapshot.get("finished", false)): finish_battle(battle_service.result())

func finish_battle(result: Dictionary) -> void:
    if finished: return
    finished = true; auto_battle = false; battle_timer.stop()
    var reward := world_service.apply_battle_result(result, GameClock.unix_time())
    SaveService.write_current()
    strike_button.disabled = true; shield_button.disabled = true; auto_button.disabled = true; retreat_button.disabled = true
    result_panel.visible = true
    var victory := bool(result.get("victory", false))
    result_title.text = "VICTORY" if victory else "WITHDRAWAL"
    result_title.modulate = Color("f4c95d") if victory else Color("e78b8b")
    result_details.text = "Rounds: %d\nRemaining troops: %d\nCasualties: %s\nRewards: %s" % [
        int(result.get("rounds", 0)), int(result.get("remaining_total", 0)),
        _dictionary_text(result.get("casualties", {})), _dictionary_text(reward)
    ]

func _refresh(snapshot: Dictionary) -> void:
    enemy_health.value = int(snapshot.get("enemy_hp", 0)); army_health.value = int(snapshot.get("player_hp", 0))
    enemy_power.text = "Power  %d" % int(snapshot.get("enemy_power", 0))
    army_power.text = "Power  %d" % int(snapshot.get("player_power", 0))
    round_label.text = "ROUND %d" % int(snapshot.get("round", 0))
    event_label.text = String(snapshot.get("last_event", "Battle begins"))
    strike_button.disabled = int(snapshot.get("commander_cooldown", 0)) > 0
    strike_button.text = "COMMANDER STRIKE" if not strike_button.disabled else "STRIKE • %d" % int(snapshot.get("commander_cooldown", 0))

func _show_invalid_battle() -> void:
    finished = true; result_panel.visible = true
    result_title.text = "NO ACTIVE BATTLE"; result_details.text = "Return to the world and select a hostile target."
    for button in [strike_button, shield_button, auto_button, retreat_button]: button.disabled = true

func _enemy_display_name(entity: Dictionary) -> String:
    if String(entity.get("kind", "")) == "PVE":
        var definition := DataRegistry.get_definition("pve", String(entity.get("pve_id", "")))
        return String(definition.get("display_name", "Hostile Creature"))
    return "Monster Camp"

func _dictionary_text(values: Dictionary) -> String:
    if values.is_empty(): return "None"
    var parts: Array[String] = []
    for key in values.keys():
        if int(values[key]) > 0: parts.append("%s %d" % [String(key).replace("troop_kingdom_", "").replace("troop_", "").capitalize(), int(values[key])])
    return ", ".join(parts) if not parts.is_empty() else "None"
