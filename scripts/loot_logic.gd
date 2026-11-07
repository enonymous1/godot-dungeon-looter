## Pure, scene-free loot logic for the dungeon-looter starter slice.
## Items are Dictionaries; every roll is passed in as a float, so
## generation is fully deterministic and headless-testable — the
## game code supplies randf() values, the tests supply exact ones.
## Rarity tiers in this slice: Normal / Magic / Rare only.
class_name LootLogic
extends RefCounted

enum Rarity { NORMAL, MAGIC, RARE }

const RARITY_NAMES := ["Normal", "Magic", "Rare"]
const RARITY_COLORS := [
	Color(0.85, 0.85, 0.85),
	Color(0.35, 0.6, 1.0),
	Color(1.0, 0.85, 0.25),
]

## Drop chance per enemy type (roll < chance drops an item).
const DROP_CHANCE := {"skeleton": 0.35, "zombie": 0.45}

const WEAPON_BASES := [
	{"name": "Rusty Sword", "min": 3, "max": 6},
	{"name": "Short Sword", "min": 5, "max": 9},
	{"name": "Broad Sword", "min": 8, "max": 12},
	{"name": "Battle Axe", "min": 10, "max": 16},
]
const ARMOR_BASES := [
	{"name": "Leather Armor", "armor": 2},
	{"name": "Chain Mail", "armor": 4},
	{"name": "Plate Armor", "armor": 6},
]
const MAGIC_PREFIXES := ["Soldier's", "Sharp", "Sturdy", "Knight's"]
const RARE_SUFFIXES := ["of the Bear", "of Power", "of the Wolf", "of Warding"]

## Affix pools per item kind. A stat never repeats on one item.
const WEAPON_AFFIX_STATS := ["damage", "strength", "vitality"]
const ARMOR_AFFIX_STATS := ["armor", "vitality", "strength"]

## Rarity roll thresholds: < 0.60 Normal, < 0.90 Magic, else Rare.
## @param roll: Float in [0, 1).
## @returns: A Rarity enum value.
static func roll_rarity(roll: float) -> int:
	if roll < 0.60:
		return Rarity.NORMAL
	if roll < 0.90:
		return Rarity.MAGIC
	return Rarity.RARE


## @param enemy_type: "skeleton" or "zombie" (unknown types never drop).
## @param roll: Float in [0, 1).
## @returns: True when the enemy drops an item.
static func roll_drop(enemy_type: String, roll: float) -> bool:
	return roll < float(DROP_CHANCE.get(enemy_type, 0.0))


## Affixes per rarity: Normal 0, Magic 1, Rare 2.
## @param rarity: A Rarity enum value.
## @returns: Affix count for that rarity.
static func affix_count_for_rarity(rarity: int) -> int:
	match rarity:
		Rarity.MAGIC:
			return 1
		Rarity.RARE:
			return 2
	return 0


## Color used for an item's name/label by rarity.
## @param rarity: A Rarity enum value.
## @returns: The rarity color.
static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


## Human-readable rarity name.
## @param rarity: A Rarity enum value.
## @returns: "Normal", "Magic", or "Rare".
static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]


## Value of one affix roll: damage/armor +2..+5, strength +1..+3,
## vitality +5..+15. Deterministic from the roll, no hidden RNG.
## @param stat: Affix stat name.
## @param roll: Float in [0, 1).
## @returns: The affix value.
static func affix_value(stat: String, roll: float) -> int:
	match stat:
		"damage", "armor":
			return 2 + int(roll * 4.0)
		"strength":
			return 1 + int(roll * 3.0)
		"vitality":
			return 5 + int(roll * 11.0)
	return 0


## Generate one item. Rolls layout: [0] base pick, [1] prefix/suffix
## pick, [2..] one roll per affix (stat pick, then value roll each).
## Missing rolls default to 0.5, so short arrays still work.
## @param kind: "weapon" or "armor".
## @param rarity: A Rarity enum value.
## @param rolls: Array of floats in [0, 1).
## @returns: Item Dictionary (kind, name, rarity, damage_min,
##   damage_max, armor, affixes, level_req).
static func generate_item(kind: String, rarity: int, rolls: Array) -> Dictionary:
	var r0: float = _roll_at(rolls, 0)
	var r1: float = _roll_at(rolls, 1)
	var item := {"kind": kind, "rarity": rarity, "damage_min": 0,
		"damage_max": 0, "armor": 0, "affixes": [], "level_req": 1}
	if kind == "armor":
		var base: Dictionary = ARMOR_BASES[clampi(int(r0 * float(ARMOR_BASES.size())), 0, ARMOR_BASES.size() - 1)]
		item["armor"] = int(base["armor"]) + rarity
		item["name"] = _named(base["name"], rarity, r1)
		item["affixes"] = _roll_affixes(ARMOR_AFFIX_STATS, rarity, rolls)
	else:
		var wbase: Dictionary = WEAPON_BASES[clampi(int(r0 * float(WEAPON_BASES.size())), 0, WEAPON_BASES.size() - 1)]
		item["damage_min"] = int(wbase["min"]) + rarity
		item["damage_max"] = int(wbase["max"]) + rarity * 2
		item["name"] = _named(wbase["name"], rarity, r1)
		item["affixes"] = _roll_affixes(WEAPON_AFFIX_STATS, rarity, rolls)
	return item


## Weapon damage range including the item's +damage affixes.
## @param item: Item Dictionary.
## @returns: {"min": int, "max": int}.
static func weapon_damage(item: Dictionary) -> Dictionary:
	var bonus := affix_total(item, "damage")
	return {"min": int(item.get("damage_min", 0)) + bonus,
		"max": int(item.get("damage_max", 0)) + bonus}


## Total armor of an armor item including +armor affixes.
## @param item: Item Dictionary.
## @returns: Armor value.
static func total_armor(item: Dictionary) -> int:
	return int(item.get("armor", 0)) + affix_total(item, "armor")


## Sum of one affix stat across an item's affixes.
## @param item: Item Dictionary.
## @param stat: Affix stat name.
## @returns: Summed value (0 when the item has no such affix).
static func affix_total(item: Dictionary, stat: String) -> int:
	var total := 0
	for affix in item.get("affixes", []):
		if affix.get("stat", "") == stat:
			total += int(affix.get("value", 0))
	return total


## One-line display string for tooltips and the loot log.
## @param item: Item Dictionary.
## @returns: e.g. "Rare Broad Sword of the Bear — 10–16 dmg, +3 dmg, +10 max HP".
static func format_item(item: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(rarity_name(int(item.get("rarity", 0))) + " " + String(item.get("name", "Item")))
	if String(item.get("kind", "")) == "weapon":
		var dmg: Dictionary = weapon_damage(item)
		parts.append(str(dmg["min"]) + "–" + str(dmg["max"]) + " dmg")
	else:
		parts.append(str(total_armor(item)) + " armor")
	for affix in item.get("affixes", []):
		parts.append("+" + str(affix.get("value", 0)) + " " + _affix_label(String(affix.get("stat", ""))))
	return " — ".join(parts)


static func _roll_at(rolls: Array, index: int) -> float:
	if index < rolls.size():
		return clampf(float(rolls[index]), 0.0, 0.999999)
	return 0.5


static func _named(base_name: String, rarity: int, roll: float) -> String:
	if rarity == Rarity.MAGIC:
		return MAGIC_PREFIXES[clampi(int(roll * float(MAGIC_PREFIXES.size())), 0, MAGIC_PREFIXES.size() - 1)] + " " + base_name
	if rarity == Rarity.RARE:
		return MAGIC_PREFIXES[clampi(int(roll * float(MAGIC_PREFIXES.size())), 0, MAGIC_PREFIXES.size() - 1)] + " " + base_name + " " + RARE_SUFFIXES[clampi(int(roll * float(RARE_SUFFIXES.size())), 0, RARE_SUFFIXES.size() - 1)]
	return base_name


static func _roll_affixes(pool: Array, rarity: int, rolls: Array) -> Array:
	var count := affix_count_for_rarity(rarity)
	var affixes: Array = []
	var used: Array = []
	var roll_index := 2
	for i in count:
		var stat_index := clampi(int(_roll_at(rolls, roll_index) * float(pool.size())), 0, pool.size() - 1)
		roll_index += 1
		# Never repeat a stat on one item: step forward to a free slot.
		var tries := 0
		while used.has(pool[stat_index]) and tries < pool.size():
			stat_index = (stat_index + 1) % pool.size()
			tries += 1
		var stat: String = pool[stat_index]
		used.append(stat)
		affixes.append({"stat": stat, "value": affix_value(stat, _roll_at(rolls, roll_index))})
		roll_index += 1
	return affixes


static func _affix_label(stat: String) -> String:
	match stat:
		"damage":
			return "dmg"
		"armor":
			return "armor"
		"strength":
			return "str"
		"vitality":
			return "max HP"
	return stat
