## Main scene for Godot Dungeon Looter v0.1.0.
## Composition root: builds the dungeon, player, enemies, and camera,
## and wires them to the HUD. It owns game flow only — all interface
## lives in LooterHUD, all formulas in the pure logic classes, and all
## per-entity behaviour in LooterPlayer / LooterEnemy / LootDrop.
## Click-to-move / click-to-attack / click-to-loot all funnel through
## _unhandled_input, so clicks on HUD buttons never move the player.
extends Node2D

const CLICK_ENEMY_RADIUS := 30.0
const CLICK_LOOT_RADIUS := 28.0
## Pickup radius must stay larger than LooterPlayer.LOOT_STOP_DIST
## (24): the player stops at 24 px, so a 32 px pickup check always
## fires on arrival instead of leaving the player circling the drop.
## The smoke test pins this invariant.
const PICKUP_RADIUS := 32.0
const LOOT_SPAWN_JITTER := 16.0
const DROP_BODY_RADIUS := 16.0
const CAMERA_SMOOTHING_SPEED := 8.0

var _player = null
var _hud: LooterHUD = null
var _enemies: Array = []
var _loot_drops: Array = []
var _kills := 0

var _camera: Camera2D


func _ready() -> void:
	_build_dungeon()
	_build_player()
	_build_enemies()
	_build_camera()
	_build_hud()
	_hud.log("Click the floor to move. Click a skeleton or zombie to attack it.")
	_hud.log("Kill things. Take their stuff. Q drinks a potion.")


func _process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		_camera.global_position = _player.global_position
		_check_loot_pickup()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drink_potion"):
		_drink_potion()
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(get_global_mouse_position())


## Route one left-click: enemy first, then loot, then bare floor.
## Enemy wins over loot on purpose — a drop under a corpse's feet
## should not steal the attack click.
## @param world_pos: Click position in dungeon coordinates.
func _handle_click(world_pos: Vector2) -> void:
	if _player == null or not _player.is_alive():
		return
	var enemy = _nearest_in_radius(_enemies, world_pos, CLICK_ENEMY_RADIUS, true)
	if enemy != null:
		_player.set_attack_target(enemy)
		_hud.log("Attacking the " + String(enemy.enemy_type) + ".")
		return
	var drop = _nearest_in_radius(_loot_drops, world_pos, CLICK_LOOT_RADIUS, false)
	if drop != null:
		_player.set_loot_target(drop)
		return
	_player.set_move_target(world_pos)


## Nearest node in `items` within `radius` of `pos`, or null.
## @param items: Array of nodes with global_position.
## @param require_alive: When true, skip nodes whose is_alive() is
##   false. Enemies need it; loot drops have no is_alive().
## @returns: The nearest matching node, or null.
func _nearest_in_radius(items: Array, pos: Vector2, radius: float, require_alive: bool):
	var best = null
	var best_dist := radius
	for item in items:
		if item == null or not is_instance_valid(item):
			continue
		if require_alive and not item.is_alive():
			continue
		var dist: float = item.global_position.distance_to(pos)
		if dist <= best_dist:
			best = item
			best_dist = dist
	return best


## Award XP for a kill and roll its loot. Runs while the enemy node
## is still alive (died is emitted before queue_free), so its
## position is valid here.
## @param enemy: The just-slain enemy node.
func _on_enemy_died(enemy) -> void:
	_kills += 1
	_hud.set_kills(_kills)
	var pos: Vector2 = enemy.global_position
	var enemy_type := String(enemy.enemy_type)
	var xp_value := int(enemy.xp_value)
	_enemies.erase(enemy)
	_player.gain_xp(xp_value)
	if LootLogic.roll_drop(enemy_type, randf()):
		var rarity := LootLogic.roll_rarity(randf())
		var kind := "weapon" if randf() < 0.5 else "armor"
		var rolls: Array = [randf(), randf(), randf(), randf(), randf(), randf(), randf()]
		var item: Dictionary = LootLogic.generate_item(kind, rarity, rolls)
		_spawn_loot(item, pos + Vector2(randf_range(-LOOT_SPAWN_JITTER, LOOT_SPAWN_JITTER), randf_range(-LOOT_SPAWN_JITTER, LOOT_SPAWN_JITTER)))
		_hud.log("The " + enemy_type + " dropped " + LootLogic.format_item(item) + ".")
	else:
		_hud.log("Slain " + enemy_type + " (+" + str(xp_value) + " XP).")


func _on_player_died() -> void:
	_hud.show_death()
	_hud.log("You died. Respawn to try again.")


func _on_player_leveled_up(new_level: int) -> void:
	_hud.log("Level up! You are now level " + str(new_level) + ". (+10 max HP, +1 potion)")


func _on_respawn() -> void:
	_player.respawn()
	_hud.hide_death()
	_hud.log("You return to the dungeon entrance.")


## Equip the item in bag slot `index`, if the slot holds anything.
## @param index: Inventory slot, from the HUD's slot_pressed signal.
func _on_inventory_slot(index: int) -> void:
	if index < 0 or index >= _player.inventory.size():
		return
	var item: Dictionary = _player.inventory[index]
	if _player.equip_item(index):
		_hud.log("Equipped " + LootLogic.format_item(item) + ".")


func _drink_potion() -> void:
	if _player == null or not _player.is_alive():
		return
	if _player.potions <= 0:
		_hud.log("No potions left.")
		return
	if _player.hp >= _player.max_hp:
		_hud.log("Already at full health.")
		return
	_player.drink_potion()
	_hud.log("Drank a potion. Potions left: " + str(_player.potions) + ".")


func _check_loot_pickup() -> void:
	var target = _player.loot_target
	if target == null or not is_instance_valid(target):
		return
	if _player.global_position.distance_to(target.global_position) > PICKUP_RADIUS:
		return
	if _player.add_item(target.item):
		_loot_drops.erase(target)
		_player.clear_loot_target()
		_hud.log("Picked up " + LootLogic.format_item(target.item) + ".")
		target.queue_free()
	else:
		_player.clear_loot_target()
		_hud.log("Inventory is full — equip something first.")


func _build_dungeon() -> void:
	var view := DungeonView.new()
	add_child(view)
	for wall in DungeonLogic.WALLS:
		_add_wall_rect(wall)
	var w := DungeonLogic.OUTER_WALL
	var size := DungeonLogic.FLOOR_SIZE
	_add_wall_rect(Rect2(0, 0, size.x, w))
	_add_wall_rect(Rect2(0, size.y - w, size.x, w))
	_add_wall_rect(Rect2(0, 0, w, size.y))
	_add_wall_rect(Rect2(size.x - w, 0, w, size.y))


func _add_wall_rect(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


func _build_player() -> void:
	_player = LooterPlayer.new()
	_player.name = "Player"
	_player.position = DungeonLogic.PLAYER_SPAWN
	add_child(_player)
	_player.died.connect(_on_player_died)
	_player.leveled_up.connect(_on_player_leveled_up)


func _build_enemies() -> void:
	for spawn in DungeonLogic.ENEMY_SPAWNS:
		var enemy = LooterEnemy.new()
		enemy.name = "Enemy_" + String(spawn["type"])
		if not enemy.setup(String(spawn["type"]), spawn["pos"]):
			# A spawn type with no stats is a data bug, not a runtime
			# condition: say so loudly and skip the spawn instead of
			# fielding a default-stat enemy with a mismatched name.
			push_error("Dungeon Looter: unknown enemy type in spawn table: " + String(spawn["type"]))
			enemy.free()
			continue
		enemy.target = _player
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		_enemies.append(enemy)


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(DungeonLogic.FLOOR_SIZE.x)
	_camera.limit_bottom = int(DungeonLogic.FLOOR_SIZE.y)
	add_child(_camera)
	_camera.make_current()


func _build_hud() -> void:
	_hud = LooterHUD.new()
	add_child(_hud)
	_hud.bind(_player)
	_hud.drink_pressed.connect(_drink_potion)
	_hud.respawn_pressed.connect(_on_respawn)
	_hud.slot_pressed.connect(_on_inventory_slot)


func _spawn_loot(item: Dictionary, pos: Vector2) -> void:
	var drop := LootDrop.new()
	drop.setup(item, DungeonLogic.clamp_to_floor(pos, DROP_BODY_RADIUS))
	add_child(drop)
	_loot_drops.append(drop)
