## The Warrior: click-to-move, click-enemy-to-attack.
## Cross-entity targets are untyped (Variant) on purpose: the player
## and the enemy both point at each other, and typed references
## would make the two scripts depend on each other's classes.
## All formulas live in CombatLogic / LootLogic; this node only
## moves, swings, and holds state.
class_name LooterPlayer
extends CharacterBody2D

signal died
signal leveled_up(new_level: int)
signal stats_changed

const INVENTORY_MAX := 12
const BODY_RADIUS := 16.0
## Stop distance when walking to a loot drop. Must stay below
## Main.PICKUP_RADIUS (32): the player stops at 24 px, so the
## pickup check always fires on arrival instead of leaving the
## player circling the drop. The smoke test pins this invariant.
const LOOT_STOP_DIST := 24.0
const MOVE_STOP_DIST := 8.0
const SWING_DURATION := 0.25

var level := 1
var xp := 0
var hp := CombatLogic.PLAYER_BASE_HP
var max_hp := CombatLogic.PLAYER_BASE_HP
var potions := CombatLogic.PLAYER_START_POTIONS
var dead := false
var inventory: Array = []
var equipped_weapon: Dictionary = {}
var equipped_armor: Dictionary = {}

var move_target := Vector2.ZERO
var has_move_target := false
var attack_target = null
var loot_target = null

var _attack_timer := 0.0
var _swing_timer := 0.0
var _facing := Vector2.RIGHT


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_recompute_max_hp()


func is_alive() -> bool:
	return not dead


## Base strength plus +str affixes from equipped gear.
## @returns: Total strength, used for the damage bonus.
func total_strength() -> int:
	return CombatLogic.PLAYER_BASE_STRENGTH + LootLogic.affix_total(equipped_weapon, "strength") + LootLogic.affix_total(equipped_armor, "strength")


## Summed +max HP affixes from equipped gear.
## @returns: Vitality bonus for max-HP calculation.
func vitality_bonus() -> int:
	return LootLogic.affix_total(equipped_weapon, "vitality") + LootLogic.affix_total(equipped_armor, "vitality")


## @returns: Total armor from the equipped armor item, or 0 bare.
func total_armor() -> int:
	if equipped_armor.is_empty():
		return 0
	return LootLogic.total_armor(equipped_armor)


## @returns: Current damage range (weapon or fists, plus strength).
func damage_range() -> Dictionary:
	return CombatLogic.player_damage_range(equipped_weapon, total_strength())


## Set a floor destination. Clears the other targets: the player has
## exactly one intention at a time, which is the classic action-RPG
## input model.
## @param pos: Destination (clamped inside the floor).
func set_move_target(pos: Vector2) -> void:
	move_target = DungeonLogic.clamp_to_floor(pos, BODY_RADIUS)
	has_move_target = true
	attack_target = null
	loot_target = null


## Chase and attack an enemy until it dies or a new target is set.
## @param enemy: The enemy node (untyped — see the class header).
func set_attack_target(enemy) -> void:
	attack_target = enemy
	loot_target = null
	has_move_target = false


## Walk to a floor drop; Main picks it up on arrival.
## @param drop: The loot drop node (untyped — see the class header).
func set_loot_target(drop) -> void:
	loot_target = drop
	attack_target = null
	has_move_target = false


func clear_loot_target() -> void:
	loot_target = null


func clear_targets() -> void:
	has_move_target = false
	attack_target = null
	loot_target = null


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _swing_timer > 0.0:
		_swing_timer -= delta
		queue_redraw()
	if _target_alive(attack_target):
		var dist: float = global_position.distance_to(attack_target.global_position)
		if dist <= CombatLogic.PLAYER_ATTACK_RANGE:
			velocity = Vector2.ZERO
			_face(attack_target.global_position)
			if _attack_timer <= 0.0:
				_attack()
		else:
			# Stop just inside attack range so the swing lands.
			_move_toward(attack_target.global_position, delta, CombatLogic.PLAYER_ATTACK_RANGE - 4.0)
	elif _target_alive(loot_target):
		_move_toward(loot_target.global_position, delta, LOOT_STOP_DIST)
	elif has_move_target:
		if _move_toward(move_target, delta, MOVE_STOP_DIST):
			has_move_target = false


func _move_toward(pos: Vector2, delta: float, stop_dist: float) -> bool:
	var to: Vector2 = pos - global_position
	if to.length() <= stop_dist:
		velocity = Vector2.ZERO
		return true
	_facing = to.normalized()
	velocity = _facing * CombatLogic.PLAYER_MOVE_SPEED
	move_and_slide()
	return false


func _face(pos: Vector2) -> void:
	var to: Vector2 = pos - global_position
	if to.length() > 1.0:
		_facing = to.normalized()


func _attack() -> void:
	_attack_timer = CombatLogic.PLAYER_ATTACK_COOLDOWN
	_swing_timer = SWING_DURATION
	queue_redraw()
	var range: Dictionary = damage_range()
	var is_crit: bool = CombatLogic.roll_crit(CombatLogic.PLAYER_CRIT_CHANCE, randf())
	# Enemies carry no armor in this slice, so the armor argument is 0
	# by design — see CombatLogic.calc_damage, not an oversight.
	var damage: int = CombatLogic.calc_damage(int(range["min"]), int(range["max"]), randf(), is_crit, 0)
	attack_target.take_damage(damage, self)


## @param amount: Damage to take (already armor-reduced by the attacker).
func take_damage(amount: int) -> void:
	if dead:
		return
	hp = maxi(0, hp - amount)
	queue_redraw()
	stats_changed.emit()
	if hp <= 0:
		dead = true
		velocity = Vector2.ZERO
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		died.emit()


## Award XP, possibly leveling up. Each level heals +10 HP and grants
## a potion: with no town in this slice, a level-up is the only
## mid-floor recovery besides the potions you started with.
## @param amount: XP just earned.
func gain_xp(amount: int) -> void:
	if dead:
		return
	var result: Dictionary = CombatLogic.apply_xp(level, xp, amount)
	var gained_levels: int = int(result["levels_gained"])
	level = int(result["level"])
	xp = int(result["xp"])
	if gained_levels > 0:
		_recompute_max_hp()
		hp = mini(max_hp, hp + CombatLogic.HP_PER_LEVEL * gained_levels)
		potions = mini(CombatLogic.PLAYER_MAX_POTIONS, potions + gained_levels)
		leveled_up.emit(level)
	stats_changed.emit()


## Drink one potion if hurt and any remain.
## @returns: False when dead, out of potions, or already at full HP.
func drink_potion() -> bool:
	if dead or potions <= 0 or hp >= max_hp:
		return false
	potions -= 1
	hp = mini(max_hp, hp + CombatLogic.potion_heal(level))
	stats_changed.emit()
	return true


## Add an item to the bag. The item is duplicated: Dictionaries are
## by reference, and the caller's copy (e.g. a floor drop's item)
## must not alias the inventory copy.
## @param item: Item Dictionary.
## @returns: False when the bag is full.
func add_item(item: Dictionary) -> bool:
	if inventory.size() >= INVENTORY_MAX:
		return false
	inventory.append(item.duplicate(true))
	stats_changed.emit()
	return true


## Equip the item in bag slot `index`, swapping the old equipped
## item back into the same slot when one is worn.
## @param index: Inventory slot.
## @returns: False for an out-of-range slot or an unknown item kind.
func equip_item(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	if String(item.get("kind", "")) == "weapon":
		_swap_equip(item, index, "weapon")
	elif String(item.get("kind", "")) == "armor":
		_swap_equip(item, index, "armor")
	else:
		return false
	_recompute_max_hp()
	stats_changed.emit()
	return true


## Unequip one slot back into the bag.
## @param kind: "weapon" or "armor".
## @returns: False when nothing is equipped there or the bag is full.
func unequip(kind: String) -> bool:
	var equipped: Dictionary = equipped_weapon if kind == "weapon" else equipped_armor
	if equipped.is_empty() or inventory.size() >= INVENTORY_MAX:
		return false
	inventory.append(equipped)
	if kind == "weapon":
		equipped_weapon = {}
	else:
		equipped_armor = {}
	_recompute_max_hp()
	stats_changed.emit()
	return true


## Revive at the entrance at full HP. Potions refill to at least 3:
## respawning with zero potions would soft-lock a new player into
## dying on the walk back.
func respawn() -> void:
	dead = false
	global_position = DungeonLogic.PLAYER_SPAWN
	_recompute_max_hp()
	hp = max_hp
	potions = maxi(potions, CombatLogic.PLAYER_START_POTIONS)
	modulate = Color.WHITE
	clear_targets()
	stats_changed.emit()


func _swap_equip(item: Dictionary, index: int, kind: String) -> void:
	var old: Dictionary = equipped_weapon if kind == "weapon" else equipped_armor
	if kind == "weapon":
		equipped_weapon = item.duplicate(true)
	else:
		equipped_armor = item.duplicate(true)
	if old.is_empty():
		inventory.remove_at(index)
	else:
		inventory[index] = old


func _recompute_max_hp() -> void:
	max_hp = CombatLogic.player_max_hp(level, vitality_bonus())
	hp = mini(hp, max_hp)


func _target_alive(target) -> bool:
	return target != null and is_instance_valid(target) and target.is_alive()


func _draw() -> void:
	var body_color := Color(0.35, 0.55, 0.9)
	if dead:
		body_color = Color(0.4, 0.4, 0.45)
	draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 24, Color(0.15, 0.2, 0.35), 2.0)
	# Sword: a short line while idle, a long swing arc right after attacking.
	var sword_len := 30.0 if _swing_timer > 0.0 else 18.0
	draw_line(Vector2.ZERO, _facing * sword_len, Color(0.9, 0.9, 0.95), 4.0)
	# HP bar above the head.
	var bar_w := 40.0
	var frac := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	draw_rect(Rect2(-bar_w / 2.0, -30.0, bar_w, 6.0), Color(0.05, 0.05, 0.05))
	draw_rect(Rect2(-bar_w / 2.0, -30.0, bar_w * frac, 6.0), Color(0.2, 0.8, 0.3))
