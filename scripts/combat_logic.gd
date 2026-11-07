## Pure, scene-free combat and progression logic.
## All randomness arrives as explicit roll floats, so every formula
## is deterministic and headless-testable; the game code supplies
## randf() values, the tests supply exact ones.
class_name CombatLogic
extends RefCounted

const PLAYER_BASE_HP := 100
const PLAYER_BASE_STRENGTH := 10
const PLAYER_BASE_DAMAGE_MIN := 4
const PLAYER_BASE_DAMAGE_MAX := 7
const PLAYER_MOVE_SPEED := 180.0
const PLAYER_ATTACK_RANGE := 48.0
const PLAYER_ATTACK_COOLDOWN := 0.6
const PLAYER_CRIT_CHANCE := 0.10
const PLAYER_START_POTIONS := 3
const PLAYER_MAX_POTIONS := 5
const HP_PER_LEVEL := 10

## Enemy table for the starter slice: two types, one floor.
## Every tuning number for a type lives here — nothing about an
## enemy's damage, speed, or attack timing is hardcoded in enemy.gd.
const ENEMY_STATS := {
	"skeleton": {"hp": 30, "damage_min": 6, "damage_max": 10,
		"xp": 25, "speed": 55.0, "attack_range": 36.0, "aggro_range": 260.0,
		"attack_cooldown": 1.0, "crit_chance": 0.05},
	"zombie": {"hp": 50, "damage_min": 8, "damage_max": 12,
		"xp": 35, "speed": 34.0, "attack_range": 36.0, "aggro_range": 220.0,
		"attack_cooldown": 1.0, "crit_chance": 0.05},
}

## XP needed to go from `level` to `level + 1`: 100 * level.
## Level 1 -> 2 costs 100, level 2 -> 3 costs 200.
## @param level: Current level (>= 1).
## @returns: XP required for the next level.
static func xp_for_next_level(level: int) -> int:
	return 100 * maxi(level, 1)


## One attack's damage. Rolls the damage range linearly, doubles on
## crit, subtracts target armor, floors at 1.
## @param damage_min: Attacker's minimum damage.
## @param damage_max: Attacker's maximum damage.
## @param damage_roll: Float in [0, 1) picking inside the range.
## @param is_crit: Whether this hit crits.
## @param target_armor: Defender's armor.
## @returns: Damage dealt, at least 1.
static func calc_damage(damage_min: int, damage_max: int, damage_roll: float, is_crit: bool, target_armor: int) -> int:
	var raw: float = float(damage_min) + (float(damage_max) - float(damage_min)) * clampf(damage_roll, 0.0, 1.0)
	if is_crit:
		raw *= 2.0
	return maxi(1, int(raw) - target_armor)


## @param crit_chance: Crit chance in [0, 1].
## @param roll: Float in [0, 1).
## @returns: True when the roll crits.
static func roll_crit(crit_chance: float, roll: float) -> bool:
	return roll < crit_chance


## Apply XP, possibly leveling up several times. Each level grants
## +10 max HP; the returned Dictionary carries the new state.
## @param level: Current level.
## @param xp: Current XP toward the next level.
## @param gained: XP just earned.
## @returns: {"level": int, "xp": int, "levels_gained": int}.
static func apply_xp(level: int, xp: int, gained: int) -> Dictionary:
	var new_level := level
	var new_xp := xp + gained
	var gained_levels := 0
	while new_xp >= xp_for_next_level(new_level):
		new_xp -= xp_for_next_level(new_level)
		new_level += 1
		gained_levels += 1
	return {"level": new_level, "xp": new_xp, "levels_gained": gained_levels}


## Max HP for a level plus vitality bonuses from equipped gear.
## @param level: Player level.
## @param vitality_bonus: Summed +max HP affixes from equipped items.
## @returns: Maximum HP.
static func player_max_hp(level: int, vitality_bonus: int) -> int:
	return PLAYER_BASE_HP + HP_PER_LEVEL * (maxi(level, 1) - 1) + vitality_bonus


## A red potion heals 30 + 10 per level (before clamping to missing HP).
## @param level: Player level.
## @returns: HP restored by one potion.
static func potion_heal(level: int) -> int:
	return 30 + 10 * maxi(level, 1)


## Player damage range: fists 4–7, plus the equipped weapon's range,
## plus total strength / 4 on both ends (integer division — a
## strength of 10 adds +2, not +2.5; the tests pin this).
## @param weapon: Equipped weapon Dictionary, or {} for fists.
## @param total_strength: Base strength plus equipped +str affixes.
## @returns: {"min": int, "max": int}.
static func player_damage_range(weapon: Dictionary, total_strength: int) -> Dictionary:
	var strength_bonus := total_strength / 4
	if weapon.is_empty():
		return {"min": PLAYER_BASE_DAMAGE_MIN + strength_bonus,
			"max": PLAYER_BASE_DAMAGE_MAX + strength_bonus}
	var dmg: Dictionary = LootLogic.weapon_damage(weapon)
	return {"min": int(dmg["min"]) + strength_bonus,
		"max": int(dmg["max"]) + strength_bonus}


## Stats row for one enemy type, or {} for an unknown type.
## @param enemy_type: "skeleton" or "zombie".
## @returns: Stats Dictionary (hp, damage_min/max, xp, speed,
##   attack_range, aggro_range, attack_cooldown, crit_chance).
static func enemy_stats(enemy_type: String) -> Dictionary:
	return ENEMY_STATS.get(enemy_type, {}).duplicate()
