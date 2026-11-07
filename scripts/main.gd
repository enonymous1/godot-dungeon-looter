## Main scene for Godot Dungeon Looter v0.1.0.
## Builds the whole game in code (the .tscn is a bare root Node2D):
## dungeon floor + walls, the Warrior, 8 fixed enemies, a camera,
## and the HUD (HP/XP bars, potions, kills, inventory, message log).
## Click-to-move / click-to-attack / click-to-loot all funnel through
## _unhandled_input, so clicks on HUD buttons never move the player.
extends Node2D

var _player = null
var _enemies: Array = []
var _loot_drops: Array = []
var _kills := 0
var _messages: Array[String] = []

var _camera: Camera2D
var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _level_label: Label
var _potions_label: Label
var _kills_label: Label
var _message_label: Label
var _weapon_label: Label
var _armor_label: Label
var _slot_buttons: Array = []
var _death_overlay: Control


func _ready() -> void:
	_build_dungeon()
	_build_player()
	_build_enemies()
	_build_camera()
	_build_hud()
	_log("Click the floor to move. Click a skeleton or zombie to attack it.")
	_log("Kill things. Take their stuff. Q drinks a potion.")


func _process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		_camera.global_position = _player.global_position
		_check_loot_pickup()
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drink_potion"):
		_drink_potion()
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(get_global_mouse_position())


func _handle_click(world_pos: Vector2) -> void:
	if _player == null or not _player.is_alive():
		return
	var enemy = _enemy_near(world_pos, 30.0)
	if enemy != null:
		_player.set_attack_target(enemy)
		_log("Attacking the " + String(enemy.enemy_type) + ".")
		return
	var drop = _loot_near(world_pos, 28.0)
	if drop != null:
		_player.set_loot_target(drop)
		return
	_player.set_move_target(world_pos)


func _on_enemy_died(enemy) -> void:
	_kills += 1
	var pos: Vector2 = enemy.global_position
	var enemy_type := String(enemy.enemy_type)
	var xp_value := int(enemy.xp_value)
	_enemies.erase(enemy)
	_player.gain_xp(xp_value)
	if LootLogic.roll_drop(enemy_type, randf()):
		var rarity := LootLogic.roll_rarity(randf())
		var kind := "weapon" if randf() < 0.5 else "armor"
		var rolls: Array = [randf(), randf(), randf(), randf(), randf(), randf()]
		var item: Dictionary = LootLogic.generate_item(kind, rarity, rolls)
		_spawn_loot(item, pos + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0)))
		_log("The " + enemy_type + " dropped " + LootLogic.format_item(item) + ".")
	else:
		_log("Slain " + enemy_type + " (+" + str(xp_value) + " XP).")


func _on_player_died() -> void:
	_death_overlay.visible = true
	_log("You died. Respawn to try again.")


func _on_player_leveled_up(new_level: int) -> void:
	_log("Level up! You are now level " + str(new_level) + ". (+10 max HP, +1 potion)")


func _on_respawn() -> void:
	_player.respawn()
	_death_overlay.visible = false
	_log("You return to the dungeon entrance.")


func _on_inventory_slot(index: int) -> void:
	if index < 0 or index >= _player.inventory.size():
		return
	var item: Dictionary = _player.inventory[index]
	if _player.equip_item(index):
		_log("Equipped " + LootLogic.format_item(item) + ".")


func _drink_potion() -> void:
	if _player == null or not _player.is_alive():
		return
	if _player.potions <= 0:
		_log("No potions left.")
		return
	if _player.hp >= _player.max_hp:
		_log("Already at full health.")
		return
	_player.drink_potion()
	_log("Drank a potion. Potions left: " + str(_player.potions) + ".")


func _check_loot_pickup() -> void:
	var target = _player.loot_target
	if target == null or not is_instance_valid(target):
		return
	if _player.global_position.distance_to(target.global_position) > 32.0:
		return
	if _player.add_item(target.item):
		_loot_drops.erase(target)
		_player.clear_loot_target()
		_log("Picked up " + LootLogic.format_item(target.item) + ".")
		target.queue_free()
	else:
		_player.clear_loot_target()
		_log("Inventory is full — equip something first.")


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
	_player.stats_changed.connect(_refresh_inventory)


func _build_enemies() -> void:
	for spawn in DungeonLogic.ENEMY_SPAWNS:
		var enemy = LooterEnemy.new()
		enemy.name = "Enemy_" + String(spawn["type"])
		enemy.setup(String(spawn["type"]), spawn["pos"])
		enemy.target = _player
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		_enemies.append(enemy)


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(DungeonLogic.FLOOR_SIZE.x)
	_camera.limit_bottom = int(DungeonLogic.FLOOR_SIZE.y)
	add_child(_camera)
	_camera.make_current()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var title := Label.new()
	title.text = "The Dark Halls — Floor 1"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -110.0
	title.offset_right = 110.0
	title.offset_top = 10.0
	title.offset_bottom = 30.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	hud.add_child(title)

	var top := VBoxContainer.new()
	top.anchor_left = 0.0
	top.anchor_top = 0.0
	top.offset_left = 12.0
	top.offset_top = 12.0
	top.offset_right = 300.0
	top.offset_bottom = 150.0
	hud.add_child(top)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 18)
	_hp_bar.show_percentage = false
	top.add_child(_hp_bar)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(260, 12)
	_xp_bar.show_percentage = false
	top.add_child(_xp_bar)
	_level_label = Label.new()
	top.add_child(_level_label)
	var potion_row := HBoxContainer.new()
	top.add_child(potion_row)
	_potions_label = Label.new()
	potion_row.add_child(_potions_label)
	var drink_button := Button.new()
	drink_button.text = "Drink (Q)"
	drink_button.pressed.connect(_drink_potion)
	potion_row.add_child(drink_button)
	_kills_label = Label.new()
	top.add_child(_kills_label)

	_message_label = Label.new()
	_message_label.anchor_left = 0.0
	_message_label.anchor_top = 1.0
	_message_label.anchor_bottom = 1.0
	_message_label.offset_left = 12.0
	_message_label.offset_top = -96.0
	_message_label.offset_right = 640.0
	_message_label.offset_bottom = -12.0
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	hud.add_child(_message_label)

	var help := Label.new()
	help.text = "Left-click: move / attack / loot    Q or 1: potion"
	help.anchor_left = 1.0
	help.anchor_top = 1.0
	help.anchor_right = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -420.0
	help.offset_top = -30.0
	help.offset_right = -12.0
	help.offset_bottom = -12.0
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	hud.add_child(help)

	_build_inventory_panel(hud)
	_build_death_overlay(hud)
	_refresh_inventory()


func _build_inventory_panel(hud: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -272.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 400.0
	hud.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "Inventory — click to equip"
	box.add_child(heading)
	_weapon_label = Label.new()
	box.add_child(_weapon_label)
	_armor_label = Label.new()
	box.add_child(_armor_label)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for i in LooterPlayer.INVENTORY_MAX:
		var button := Button.new()
		button.custom_minimum_size = Vector2(78, 44)
		button.text = "—"
		button.disabled = true
		button.set_meta("slot", i)
		button.pressed.connect(_on_slot_button.bind(button))
		grid.add_child(button)
		_slot_buttons.append(button)
	var hint := Label.new()
	hint.text = "Weapons and armor you pick up land here."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)


func _on_slot_button(button: Button) -> void:
	_on_inventory_slot(int(button.get_meta("slot", -1)))


func _build_death_overlay(hud: CanvasLayer) -> void:
	_death_overlay = Control.new()
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.visible = false
	hud.add_child(_death_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.add_child(center)
	var box := VBoxContainer.new()
	center.add_child(box)
	var label := Label.new()
	label.text = "You died."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	box.add_child(label)
	var respawn_button := Button.new()
	respawn_button.text = "Respawn at the entrance"
	respawn_button.pressed.connect(_on_respawn)
	box.add_child(respawn_button)


func _refresh_inventory() -> void:
	if _player == null:
		return
	for i in _slot_buttons.size():
		var button: Button = _slot_buttons[i]
		if i < _player.inventory.size():
			var item: Dictionary = _player.inventory[i]
			button.text = String(item.get("name", "Item")).left(13)
			button.tooltip_text = LootLogic.format_item(item)
			button.add_theme_color_override("font_color", LootLogic.rarity_color(int(item.get("rarity", 0))))
			button.disabled = false
		else:
			button.text = "—"
			button.tooltip_text = ""
			button.disabled = true
	_weapon_label.text = "Weapon: " + (_short_equipped(_player.equipped_weapon, "fists"))
	_armor_label.text = "Armor: " + (_short_equipped(_player.equipped_armor, "none"))


func _short_equipped(item: Dictionary, fallback: String) -> String:
	if item.is_empty():
		return fallback
	return LootLogic.format_item(item)


func _update_hud() -> void:
	if _player == null:
		return
	_hp_bar.max_value = _player.max_hp
	_hp_bar.value = _player.hp
	_xp_bar.max_value = CombatLogic.xp_for_next_level(_player.level)
	_xp_bar.value = _player.xp
	_level_label.text = "Level " + str(_player.level) + "  —  " + str(_player.xp) + " / " + str(CombatLogic.xp_for_next_level(_player.level)) + " XP"
	_potions_label.text = "Potions: " + str(_player.potions)
	_kills_label.text = "Kills: " + str(_kills) + " / 8"


func _log(text: String) -> void:
	_messages.append(text)
	while _messages.size() > 4:
		_messages.remove_at(0)
	_message_label.text = "\n".join(_messages)


func _enemy_near(pos: Vector2, radius: float):
	var best = null
	var best_dist := radius
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var dist: float = enemy.global_position.distance_to(pos)
		if dist <= best_dist:
			best = enemy
			best_dist = dist
	return best


func _loot_near(pos: Vector2, radius: float):
	var best = null
	var best_dist := radius
	for drop in _loot_drops:
		if drop == null or not is_instance_valid(drop):
			continue
		var dist: float = drop.global_position.distance_to(pos)
		if dist <= best_dist:
			best = drop
			best_dist = dist
	return best


func _spawn_loot(item: Dictionary, pos: Vector2) -> void:
	var drop := LootDrop.new()
	drop.setup(item, DungeonLogic.clamp_to_floor(pos, 16.0))
	add_child(drop)
	_loot_drops.append(drop)
