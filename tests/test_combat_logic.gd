## Headless tests for CombatLogic. Run with:
##   godot --headless --path . -s res://tests/test_combat_logic.gd
## Prints PASS n/n or FAIL ... and quits with exit code 0/1.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_run_all()
	if _failed == 0:
		print("PASS " + str(_passed) + "/" + str(_passed))
		quit(0)
	else:
		print("FAIL " + str(_failed) + " of " + str(_passed + _failed) + " checks failed")
		quit(1)


func _check(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + test_name)


func _run_all() -> void:
	# XP curve.
	_check(CombatLogic.xp_for_next_level(1) == 100, "level 1 -> 2 costs 100 XP")
	_check(CombatLogic.xp_for_next_level(2) == 200, "level 2 -> 3 costs 200 XP")
	_check(CombatLogic.xp_for_next_level(3) == 300, "level 3 -> 4 costs 300 XP")
	# Damage: range roll, crit, armor, floor of 1.
	_check(CombatLogic.calc_damage(6, 10, 0.0, false, 0) == 6, "damage roll 0 gives min")
	_check(CombatLogic.calc_damage(6, 10, 1.0, false, 0) == 10, "damage roll 1 gives max")
	_check(CombatLogic.calc_damage(6, 10, 0.0, true, 0) == 12, "crit doubles damage")
	_check(CombatLogic.calc_damage(6, 10, 0.0, false, 5) == 1, "armor reduces damage to 1")
	_check(CombatLogic.calc_damage(4, 7, 0.0, false, 100) == 1, "damage never drops below 1")
	# Crit rolls.
	_check(CombatLogic.roll_crit(0.10, 0.05), "crit roll under chance crits")
	_check(not CombatLogic.roll_crit(0.10, 0.10), "crit roll at chance does not crit")
	_check(not CombatLogic.roll_crit(0.10, 0.5), "crit roll over chance does not crit")
	# XP application, including a double level-up.
	var stay: Dictionary = CombatLogic.apply_xp(1, 0, 25)
	_check(int(stay["level"]) == 1 and int(stay["xp"]) == 25 and int(stay["levels_gained"]) == 0, "25 XP stays level 1")
	var up: Dictionary = CombatLogic.apply_xp(1, 90, 25)
	_check(int(up["level"]) == 2 and int(up["xp"]) == 15 and int(up["levels_gained"]) == 1, "90 + 25 XP levels up with 15 left over")
	var double: Dictionary = CombatLogic.apply_xp(1, 0, 300)
	_check(int(double["level"]) == 3 and int(double["xp"]) == 0 and int(double["levels_gained"]) == 2, "300 XP is exactly two level-ups")
	# Max HP and potions.
	_check(CombatLogic.player_max_hp(1, 0) == 100, "level 1 max HP is 100")
	_check(CombatLogic.player_max_hp(2, 0) == 110, "level 2 max HP is 110")
	_check(CombatLogic.player_max_hp(1, 15) == 115, "vitality bonus raises max HP")
	_check(CombatLogic.potion_heal(1) == 40, "level 1 potion heals 40")
	_check(CombatLogic.potion_heal(3) == 60, "level 3 potion heals 60")
	# Player damage range: fists plus strength, weapon plus strength.
	var fists: Dictionary = CombatLogic.player_damage_range({}, 10)
	_check(int(fists["min"]) == 6 and int(fists["max"]) == 9, "fists with 10 strength are 6-9")
	var sword := {"damage_min": 8, "damage_max": 12, "affixes": [{"stat": "damage", "value": 3}]}
	var armed: Dictionary = CombatLogic.player_damage_range(sword, 12)
	_check(int(armed["min"]) == 14 and int(armed["max"]) == 18, "weapon damage plus strength bonus")
	# Enemy table.
	var skeleton: Dictionary = CombatLogic.enemy_stats("skeleton")
	_check(int(skeleton["hp"]) == 30 and int(skeleton["xp"]) == 25, "skeleton is 30 HP, 25 XP")
	var zombie: Dictionary = CombatLogic.enemy_stats("zombie")
	_check(int(zombie["hp"]) == 50 and int(zombie["speed"]) == 34, "zombie is 50 HP, slower than skeleton")
	_check(CombatLogic.enemy_stats("demon").is_empty(), "unknown enemy type has no stats")
