## LooterHUD: every on-screen interface element — HP/XP bars, level,
## potions, kills, the message log, the inventory panel, and the
## death overlay. Owned by Main; it never touches game state except
## through the player it is bound to, and it never spawns, kills,
## or moves anything.
## Main drives it (log, show_death, hide_death, set_kills); the
## player drives its bars through stats_changed, so nothing polls
## the HUD once per frame.
## Call bind() after the HUD is in the tree (_ready builds the
## controls); the stats connection is made there.
class_name LooterHUD
extends CanvasLayer

signal drink_pressed
signal respawn_pressed
signal slot_pressed(index: int)

const MESSAGE_HISTORY := 4
const SLOT_NAME_LENGTH := 13

var slot_buttons: Array = []

var _player = null
var _kills := 0
var _messages: Array[String] = []

var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _level_label: Label
var _potions_label: Label
var _kills_label: Label
var _message_label: Label
var _weapon_label: Label
var _armor_label: Label
var _death_overlay: Control


func _ready() -> void:
	_build()


## Bind the HUD to the player. Bars and inventory refresh on
## stats_changed from here on; Main only pushes kills and messages.
## @param player: The LooterPlayer node (untyped — see LooterPlayer).
func bind(player) -> void:
	_player = player
	_player.stats_changed.connect(_on_player_stats_changed)
	update_hud()
	refresh_inventory()


## Refresh bars and labels from the bound player and kill count.
func update_hud() -> void:
	if _player == null:
		return
	_hp_bar.max_value = _player.max_hp
	_hp_bar.value = _player.hp
	_xp_bar.max_value = CombatLogic.xp_for_next_level(_player.level)
	_xp_bar.value = _player.xp
	_level_label.text = "Level " + str(_player.level) + "  —  " + str(_player.xp) + " / " + str(CombatLogic.xp_for_next_level(_player.level)) + " XP"
	_potions_label.text = "Potions: " + str(_player.potions)
	_kills_label.text = "Kills: " + str(_kills) + " / " + str(DungeonLogic.total_enemies())


## Record a kill total and refresh the kills label.
## @param kills: Enemies slain so far.
func set_kills(kills: int) -> void:
	_kills = kills
	update_hud()


## Rebuild the inventory grid and equipped labels from the player.
func refresh_inventory() -> void:
	if _player == null:
		return
	for i in slot_buttons.size():
		var button: Button = slot_buttons[i]
		if i < _player.inventory.size():
			var item: Dictionary = _player.inventory[i]
			button.text = String(item.get("name", "Item")).left(SLOT_NAME_LENGTH)
			button.tooltip_text = LootLogic.format_item(item)
			button.add_theme_color_override("font_color", LootLogic.rarity_color(int(item.get("rarity", 0))))
			button.disabled = false
		else:
			button.text = "—"
			button.tooltip_text = ""
			button.disabled = true
	_weapon_label.text = "Weapon: " + _short_equipped(_player.equipped_weapon, "fists")
	_armor_label.text = "Armor: " + _short_equipped(_player.equipped_armor, "none")


## Append a line to the message log, keeping the last few.
## @param text: Message line.
func log(text: String) -> void:
	_messages.append(text)
	while _messages.size() > MESSAGE_HISTORY:
		_messages.remove_at(0)
	_message_label.text = "\n".join(_messages)


func show_death() -> void:
	_death_overlay.visible = true


func hide_death() -> void:
	_death_overlay.visible = false


## @returns: Number of inventory slots (12 in this slice).
func get_slot_count() -> int:
	return slot_buttons.size()


## @returns: True while the death overlay is visible.
func is_death_visible() -> bool:
	return _death_overlay.visible


func _on_player_stats_changed() -> void:
	update_hud()
	refresh_inventory()


func _short_equipped(item: Dictionary, fallback: String) -> String:
	if item.is_empty():
		return fallback
	return LootLogic.format_item(item)


func _build() -> void:
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
	add_child(title)

	var top := VBoxContainer.new()
	top.anchor_left = 0.0
	top.anchor_top = 0.0
	top.offset_left = 12.0
	top.offset_top = 12.0
	top.offset_right = 300.0
	top.offset_bottom = 150.0
	add_child(top)

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
	drink_button.pressed.connect(func() -> void: drink_pressed.emit())
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
	add_child(_message_label)

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
	add_child(help)

	_build_inventory_panel()
	_build_death_overlay()


func _build_inventory_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -272.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 400.0
	add_child(panel)
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
		slot_buttons.append(button)
	var hint := Label.new()
	hint.text = "Weapons and armor you pick up land here."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)


func _on_slot_button(button: Button) -> void:
	slot_pressed.emit(int(button.get_meta("slot", -1)))


func _build_death_overlay() -> void:
	_death_overlay = Control.new()
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.visible = false
	add_child(_death_overlay)
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
	respawn_button.pressed.connect(func() -> void: respawn_pressed.emit())
	box.add_child(respawn_button)
