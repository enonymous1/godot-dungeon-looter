## A dungeon enemy: stands idle until the player comes into aggro
## range, chases, and attacks in range. Dies to a died signal (the
## main scene awards XP and rolls loot before the node frees).
class_name LooterEnemy
extends CharacterBody2D

signal died(enemy)

var enemy_type := "skeleton"
var hp := 30
var max_hp := 30
var damage_min := 6
var damage_max := 10
var xp_value := 25
var speed := 55.0
var attack_range := 36.0
var aggro_range := 260.0
var target = null
var dead := false

var _attack_timer := 0.0
var _flash_timer := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1


func setup(type: String, pos: Vector2) -> void:
	var stats: Dictionary = CombatLogic.enemy_stats(type)
	if stats.is_empty():
		return
	enemy_type = type
	max_hp = int(stats["hp"])
	hp = max_hp
	damage_min = int(stats["damage_min"])
	damage_max = int(stats["damage_max"])
	xp_value = int(stats["xp"])
	speed = float(stats["speed"])
	attack_range = float(stats["attack_range"])
	aggro_range = float(stats["aggro_range"])
	global_position = pos
	collision_layer = 2
	collision_mask = 1


func is_alive() -> bool:
	return not dead


func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		queue_redraw()
	if target == null or not is_instance_valid(target) or not target.is_alive():
		velocity = Vector2.ZERO
		return
	var to: Vector2 = target.global_position - global_position
	var dist := to.length()
	if dist > aggro_range:
		velocity = Vector2.ZERO
		return
	if dist > attack_range:
		velocity = to.normalized() * speed
		move_and_slide()
	elif _attack_timer <= 0.0:
		_attack()


func _attack() -> void:
	_attack_timer = 1.0
	var target_armor := 0
	if target != null and is_instance_valid(target):
		target_armor = target.total_armor()
	var damage: int = CombatLogic.calc_damage(damage_min, damage_max, randf(), CombatLogic.roll_crit(0.05, randf()), target_armor)
	target.take_damage(damage)


func take_damage(amount: int, _from) -> void:
	if dead:
		return
	hp = maxi(0, hp - amount)
	_flash_timer = 0.12
	queue_redraw()
	if hp <= 0:
		dead = true
		died.emit(self)
		queue_free()


func _draw() -> void:
	var radius := 14.0
	var body_color := Color(0.9, 0.9, 0.85)
	if enemy_type == "zombie":
		radius = 15.0
		body_color = Color(0.45, 0.7, 0.3)
	if _flash_timer > 0.0:
		body_color = Color.WHITE
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.1, 0.1, 0.1), 2.0)
	# Eyes.
	draw_circle(Vector2(-5, -3), 2.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(5, -3), 2.0, Color(0.1, 0.1, 0.1))
	# HP bar, only once hurt.
	if hp < max_hp:
		var bar_w := 30.0
		var frac := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
		draw_rect(Rect2(-bar_w / 2.0, -28.0, bar_w, 5.0), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(-bar_w / 2.0, -28.0, bar_w * frac, 5.0), Color(0.9, 0.2, 0.2))
