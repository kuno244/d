class_name BattleService
extends RefCounted

var battle: Dictionary = {}
var source_troops: Dictionary = {}
var power_per_unit: Dictionary = {}
var rng := RandomNumberGenerator.new()

func start(troops: Dictionary, troop_power: Dictionary, enemy_power: int, seed_value: int) -> Dictionary:
    source_troops = troops.duplicate(true)
    power_per_unit = troop_power.duplicate(true)
    var player_power := 0
    for troop_id in source_troops.keys():
        player_power += maxi(0, int(source_troops[troop_id])) * maxi(0, int(power_per_unit.get(troop_id, 0)))
    rng.seed = seed_value
    battle = {
        "round": 0, "player_power": maxi(1, player_power), "enemy_power": maxi(1, enemy_power),
        "player_hp": maxi(100, player_power * 8), "player_max_hp": maxi(100, player_power * 8),
        "enemy_hp": maxi(100, enemy_power * 8), "enemy_max_hp": maxi(100, enemy_power * 8),
        "commander_cooldown": 0, "finished": false, "victory": false, "last_event": "Armies take formation"
    }
    return snapshot()

func step(action: String = "STANDARD") -> Dictionary:
    if battle.is_empty() or bool(battle.get("finished", false)): return snapshot()
    battle["round"] = int(battle.get("round", 0)) + 1
    battle["commander_cooldown"] = maxi(0, int(battle.get("commander_cooldown", 0)) - 1)
    var player_multiplier := 1.0
    var enemy_multiplier := 1.0
    var event_text := "Vanguard presses the attack"
    if action == "COMMANDER_STRIKE" and int(battle.get("commander_cooldown", 0)) == 0:
        player_multiplier = 1.9; battle["commander_cooldown"] = 3; event_text = "Commander Strike breaks the enemy line"
    elif action == "SHIELD_WALL":
        player_multiplier = 0.72; enemy_multiplier = 0.42; event_text = "Shield Wall absorbs the counterattack"
    var player_damage := maxi(1, roundi(float(battle["player_power"]) * 0.23 * player_multiplier * rng.randf_range(0.92, 1.08)))
    battle["enemy_hp"] = maxi(0, int(battle["enemy_hp"]) - player_damage)
    var enemy_damage := 0
    if int(battle["enemy_hp"]) > 0:
        enemy_damage = maxi(1, roundi(float(battle["enemy_power"]) * 0.14 * enemy_multiplier * rng.randf_range(0.9, 1.1)))
        battle["player_hp"] = maxi(0, int(battle["player_hp"]) - enemy_damage)
    battle["last_event"] = "%s  •  %d dealt / %d taken" % [event_text, player_damage, enemy_damage]
    if int(battle["enemy_hp"]) <= 0 or int(battle["player_hp"]) <= 0:
        battle["finished"] = true
        battle["victory"] = int(battle["enemy_hp"]) <= 0 and int(battle["player_hp"]) > 0
    return snapshot()

func retreat() -> Dictionary:
    if battle.is_empty(): return {}
    battle["player_hp"] = maxi(1, int(float(battle.get("player_max_hp", 1)) * 0.92))
    battle["finished"] = true; battle["victory"] = false; battle["last_event"] = "The Vanguard retreats in good order"
    return result()

func snapshot() -> Dictionary:
    return battle.duplicate(true)

func result() -> Dictionary:
    if battle.is_empty(): return {}
    var casualty_ratio := clampf(1.0 - float(battle.get("player_hp", 0)) / maxf(1.0, float(battle.get("player_max_hp", 1))), 0.0, 1.0)
    var casualties: Dictionary = {}; var remaining: Dictionary = {}
    for troop_id in source_troops.keys():
        var count := maxi(0, int(source_troops[troop_id]))
        var lost := mini(count, roundi(float(count) * casualty_ratio))
        casualties[troop_id] = lost; remaining[troop_id] = count - lost
    return {
        "victory": bool(battle.get("victory", false)), "rounds": int(battle.get("round", 0)),
        "player_power": int(battle.get("player_power", 0)), "enemy_power": int(battle.get("enemy_power", 0)),
        "casualty_ratio": casualty_ratio, "casualties": casualties, "remaining": remaining,
        "remaining_total": _sum_values(remaining)
    }

func _sum_values(values: Dictionary) -> int:
    var total := 0
    for value in values.values(): total += int(value)
    return total
