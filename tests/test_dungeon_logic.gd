## Headless tests for DungeonLogic. Run with:
##   godot --headless --path . -s res://tests/test_dungeon_logic.gd
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
	_check(DungeonLogic.FLOOR_SIZE == Vector2(1600, 1200), "floor is 1600x1200")
	_check(DungeonLogic.is_walkable(DungeonLogic.PLAYER_SPAWN, 20.0), "player spawn is walkable")
	# Every enemy spawn is walkable and inside the floor.
	var skeletons := 0
	var zombies := 0
	for spawn in DungeonLogic.ENEMY_SPAWNS:
		var pos: Vector2 = spawn["pos"]
		_check(DungeonLogic.is_walkable(pos, 20.0), "enemy spawn at " + str(pos) + " is walkable")
		_check(pos.x > 0.0 and pos.x < DungeonLogic.FLOOR_SIZE.x and pos.y > 0.0 and pos.y < DungeonLogic.FLOOR_SIZE.y, "enemy spawn at " + str(pos) + " is inside the floor")
		if String(spawn["type"]) == "skeleton":
			skeletons += 1
		elif String(spawn["type"]) == "zombie":
			zombies += 1
	_check(DungeonLogic.ENEMY_SPAWNS.size() == 8, "floor has 8 enemy spawns")
	_check(skeletons == 5, "floor has 5 skeletons")
	_check(zombies == 3, "floor has 3 zombies")
	# Walls block, door gaps do not.
	_check(not DungeonLogic.is_walkable(Vector2(780, 300), 20.0), "vertical wall blocks movement")
	_check(not DungeonLogic.is_walkable(Vector2(200, 580), 20.0), "horizontal wall blocks movement")
	_check(DungeonLogic.is_walkable(Vector2(800, 600), 20.0), "vertical wall door gap is walkable")
	_check(DungeonLogic.is_walkable(Vector2(600, 600), 20.0), "horizontal wall door gap is walkable")
	_check(not DungeonLogic.is_walkable(Vector2(0, 0), 20.0), "outside the floor is not walkable")
	# Clamping.
	_check(DungeonLogic.clamp_to_floor(Vector2(-100, -100), 20.0) == Vector2(52, 52), "clamp pulls a point inside the floor")
	_check(DungeonLogic.clamp_to_floor(Vector2(2000, 2000), 20.0) == Vector2(1548, 1148), "clamp pulls a far point back inside")
