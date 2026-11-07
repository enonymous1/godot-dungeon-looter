## Headless scene smoke test: instantiates the main scene and drives
## the real gameplay path (target, kill, loot, equip, XP, potion,
## death, respawn). Run with:
##   godot --headless --path . -s res://tests/test_scene_smoke.gd
## Prints PASS n/n or FAIL ... and quits with exit code 0/1.
## Note: the scene is verified to build and run, not to render
## (headless has no rasterizer).
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _checked: bool = false
var _main: Node2D = null


func _init() -> void:
	# _ready on added nodes is not flushed until the first iteration,
	# so only build the scene here; checks run in _process.
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "main scene loads")
	_main = packed.instantiate()
	root.add_child(_main)


## Run the checks on the first frame, once _ready has run, then quit.
## @param _delta: Frame time (unused).
## @returns: True (keeps the loop running until quit() takes effect).
func _process(_delta: float) -> bool:
	if _checked:
		return true
	_checked = true
	_run_all()
	if _failed == 0:
		print("PASS " + str(_passed) + "/" + str(_passed))
		quit(0)
	else:
		print("FAIL " + str(_failed) + " of " + str(_passed + _failed) + " checks failed")
		quit(1)
	return true


func _check(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + test_name)


func _run_all() -> void:
	var player = _main._player
	_check(player != null, "player exists")
	_check(player.hp == 100 and player.level == 1 and player.potions == 3, "player starts at 100 HP, level 1, 3 potions")
	_check(player.inventory.is_empty(), "player starts with an empty inventory")
	_check(player.is_alive(), "player starts alive")
	_check(_main._enemies.size() == 8, "floor starts with 8 enemies")
	var alive := 0
	for enemy in _main._enemies:
		if enemy.is_alive() and int(enemy.hp) > 0:
			alive += 1
	_check(alive == 8, "all 8 enemies start alive")
	_check(_main._hp_bar != null and _main._xp_bar != null, "HUD bars exist")
	_check(_main._slot_buttons.size() == 12, "inventory grid has 12 slots")
	_check(_main._camera != null and _main._camera.limit_right == 1600, "camera exists with floor limits")
	var has_view := false
	for child in _main.get_children():
		if child is DungeonView:
			has_view = true
	_check(has_view, "dungeon view exists")
	# Target an enemy and kill it: XP is awarded and the kill counts.
	var enemy = _main._enemies[0]
	player.set_attack_target(enemy)
	_check(player.attack_target == enemy, "clicking an enemy sets it as the attack target")
	enemy.take_damage(1000, null)
	_check(_main._kills == 1, "killing an enemy counts a kill")
	_check(_main._enemies.size() == 7, "dead enemy leaves the enemy list")
	_check(player.xp == 25 or player.level == 2, "killing a skeleton awards its XP")
	# Loot: give the player a Rare weapon, equip it, damage rises.
	var item: Dictionary = LootLogic.generate_item("weapon", LootLogic.Rarity.RARE, [0.99, 0.0, 0.0, 0.0, 0.0, 0.0])
	_check(player.add_item(item), "loot fits in the inventory")
	_check(player.equip_item(0), "loot equips from slot 0")
	_check(not player.equipped_weapon.is_empty(), "weapon slot is filled after equip")
	var armed: Dictionary = player.damage_range()
	_check(int(armed["min"]) > 6, "equipped Rare weapon beats fists (min " + str(armed["min"]) + ")")
	# XP, potion, death, respawn on the real player node.
	player.gain_xp(100)
	_check(player.level == 2, "100 XP levels the player to 2")
	player.take_damage(50)
	var hp_before: int = player.hp
	var potions_before: int = player.potions
	_check(player.drink_potion(), "potion drinks while hurt")
	_check(player.hp > hp_before and player.potions == potions_before - 1, "potion heals and spends one potion")
	player.take_damage(9999)
	_check(not player.is_alive(), "lethal damage kills the player")
	_check(_main._death_overlay.visible, "death overlay shows on death")
	_main._on_respawn()
	_check(player.is_alive() and player.hp == player.max_hp, "respawn revives at full HP")
	_check(player.global_position == DungeonLogic.PLAYER_SPAWN, "respawn returns the player to the entrance")
	# A loot drop can be spawned on the floor.
	_main._spawn_loot(item, Vector2(400, 400))
	_check(_main._loot_drops.size() >= 1, "loot drop spawns on the floor")
