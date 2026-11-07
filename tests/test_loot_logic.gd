## Headless tests for LootLogic. Run with:
##   godot --headless --path . -s res://tests/test_loot_logic.gd
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
	# Rarity thresholds.
	_check(LootLogic.roll_rarity(0.0) == LootLogic.Rarity.NORMAL, "rarity 0.0 is Normal")
	_check(LootLogic.roll_rarity(0.59) == LootLogic.Rarity.NORMAL, "rarity 0.59 is Normal")
	_check(LootLogic.roll_rarity(0.60) == LootLogic.Rarity.MAGIC, "rarity 0.60 is Magic")
	_check(LootLogic.roll_rarity(0.89) == LootLogic.Rarity.MAGIC, "rarity 0.89 is Magic")
	_check(LootLogic.roll_rarity(0.90) == LootLogic.Rarity.RARE, "rarity 0.90 is Rare")
	_check(LootLogic.roll_rarity(0.99) == LootLogic.Rarity.RARE, "rarity 0.99 is Rare")
	# Drop chances.
	_check(LootLogic.roll_drop("skeleton", 0.34), "skeleton drops at 0.34")
	_check(not LootLogic.roll_drop("skeleton", 0.35), "skeleton does not drop at 0.35")
	_check(LootLogic.roll_drop("zombie", 0.44), "zombie drops at 0.44")
	_check(not LootLogic.roll_drop("zombie", 0.45), "zombie does not drop at 0.45")
	_check(not LootLogic.roll_drop("demon", 0.0), "unknown enemy never drops")
	# Affix counts.
	_check(LootLogic.affix_count_for_rarity(LootLogic.Rarity.NORMAL) == 0, "Normal has 0 affixes")
	_check(LootLogic.affix_count_for_rarity(LootLogic.Rarity.MAGIC) == 1, "Magic has 1 affix")
	_check(LootLogic.affix_count_for_rarity(LootLogic.Rarity.RARE) == 2, "Rare has 2 affixes")
	# Affix values.
	_check(LootLogic.affix_value("damage", 0.0) == 2, "damage affix min is +2")
	_check(LootLogic.affix_value("damage", 0.999) == 5, "damage affix max is +5")
	_check(LootLogic.affix_value("strength", 0.0) == 1, "strength affix min is +1")
	_check(LootLogic.affix_value("strength", 0.999) == 3, "strength affix max is +3")
	_check(LootLogic.affix_value("vitality", 0.0) == 5, "vitality affix min is +5")
	_check(LootLogic.affix_value("vitality", 0.999) == 15, "vitality affix max is +15")
	# Normal weapon: no affixes, base stats, plain name.
	var rusty: Dictionary = LootLogic.generate_item("weapon", LootLogic.Rarity.NORMAL, [0.0, 0.0])
	_check(String(rusty["name"]) == "Rusty Sword", "Normal weapon keeps its plain base name")
	_check(int(rusty["damage_min"]) == 3 and int(rusty["damage_max"]) == 6, "Rusty Sword is 3-6")
	_check((rusty["affixes"] as Array).is_empty(), "Normal weapon has no affixes")
	# Rare weapon: rarity bonus + 2 distinct affixes + prefix/suffix name.
	var rare: Dictionary = LootLogic.generate_item("weapon", LootLogic.Rarity.RARE, [0.99, 0.0, 0.0, 0.0, 0.0, 0.0])
	_check(String(rare["name"]) == "Soldier's Battle Axe of the Bear", "Rare weapon name has prefix and suffix")
	_check(int(rare["damage_min"]) == 12 and int(rare["damage_max"]) == 20, "Rare Battle Axe is 12-20")
	_check((rare["affixes"] as Array).size() == 2, "Rare weapon has 2 affixes")
	var rare_stats: Array = []
	for affix in rare["affixes"]:
		rare_stats.append(affix["stat"])
	_check(rare_stats[0] != rare_stats[1], "Rare affix stats are distinct")
	_check(int(rare["affixes"][0]["value"]) == 2, "first Rare affix is +2 damage")
	# Prefix and suffix roll independently: same prefix roll (0.0),
	# different suffix roll (0.99) must give a different suffix.
	var varied: Dictionary = LootLogic.generate_item("weapon", LootLogic.Rarity.RARE, [0.99, 0.0, 0.99, 0.0, 0.0, 0.0, 0.0])
	_check(String(varied["name"]) == "Soldier's Battle Axe of Warding", "prefix and suffix roll independently")
	# Unknown kinds generate nothing instead of a silent weapon.
	_check(LootLogic.generate_item("potion", LootLogic.Rarity.NORMAL, [0.0]).is_empty(), "unknown item kind generates nothing")
	# Magic armor: Chain Mail base, +1 rarity armor, 1 affix, prefixed name.
	var mail: Dictionary = LootLogic.generate_item("armor", LootLogic.Rarity.MAGIC, [0.5, 0.0, 0.0, 0.0])
	_check(String(mail["name"]) == "Soldier's Chain Mail", "Magic armor name has a prefix")
	_check(int(mail["armor"]) == 5, "Magic Chain Mail is 5 armor")
	_check((mail["affixes"] as Array).size() == 1, "Magic armor has 1 affix")
	# Derived stats.
	var sword := {"damage_min": 8, "damage_max": 12, "affixes": [{"stat": "damage", "value": 3}]}
	var dmg: Dictionary = LootLogic.weapon_damage(sword)
	_check(int(dmg["min"]) == 11 and int(dmg["max"]) == 15, "+damage affix raises weapon damage")
	var plate := {"armor": 4, "affixes": [{"stat": "armor", "value": 2}]}
	_check(LootLogic.total_armor(plate) == 6, "+armor affix raises armor")
	_check(LootLogic.affix_total(sword, "damage") == 3, "affix_total sums damage")
	_check(LootLogic.affix_total(sword, "vitality") == 0, "affix_total is 0 for a missing stat")
	# Display strings and rarity helpers.
	_check(LootLogic.format_item(rare).begins_with("Rare Soldier's Battle Axe of the Bear"), "format_item starts with rarity and name")
	_check("dmg" in LootLogic.format_item(rare), "format_item shows weapon damage")
	_check("armor" in LootLogic.format_item(mail), "format_item shows armor value")
	_check(LootLogic.rarity_name(LootLogic.Rarity.RARE) == "Rare", "rarity_name Rare")
	_check(LootLogic.rarity_color(LootLogic.Rarity.NORMAL) != LootLogic.rarity_color(LootLogic.Rarity.RARE), "rarity colors differ")
