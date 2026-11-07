## Pure, scene-free dungeon layout for the starter slice: one floor,
## 1600x1200, three interior walls with door gaps, fixed spawns.
## The game builds collision bodies from WALLS; the tests assert
## every spawn is walkable and inside the floor.
## A second floor wants a DungeonFloor resource holding these same
## fields, not a second copy of this class.
class_name DungeonLogic
extends RefCounted

const FLOOR_SIZE := Vector2(1600.0, 1200.0)
const OUTER_WALL := 32.0
const PLAYER_SPAWN := Vector2(200.0, 640.0)

## Interior walls (door gaps: vertical wall gap y 480–720,
## horizontal wall gap x 480–760). Outer bounds are implicit.
const WALLS := [
	Rect2(760, 32, 40, 448),
	Rect2(760, 720, 40, 448),
	Rect2(32, 560, 448, 40),
]

## Fixed enemy spawns: 5 skeletons, 3 zombies.
const ENEMY_SPAWNS := [
	{"type": "skeleton", "pos": Vector2(400, 300)},
	{"type": "skeleton", "pos": Vector2(1200, 300)},
	{"type": "skeleton", "pos": Vector2(1200, 900)},
	{"type": "skeleton", "pos": Vector2(500, 900)},
	{"type": "skeleton", "pos": Vector2(900, 200)},
	{"type": "zombie", "pos": Vector2(1000, 600)},
	{"type": "zombie", "pos": Vector2(1300, 600)},
	{"type": "zombie", "pos": Vector2(900, 1000)},
]

## Torch positions (visual only, drawn by DungeonView).
const TORCHES := [
	Vector2(120, 120), Vector2(1480, 120), Vector2(120, 1080),
	Vector2(1480, 1080), Vector2(800, 600),
]

## @returns: Number of enemies on this floor (8 in this slice).
static func total_enemies() -> int:
	return ENEMY_SPAWNS.size()


## @param pos: Point to test.
## @param radius: Body radius to keep clear of walls and bounds.
## @returns: True when a body of that radius can stand at pos.
static func is_walkable(pos: Vector2, radius: float) -> bool:
	if pos.x < OUTER_WALL + radius or pos.x > FLOOR_SIZE.x - OUTER_WALL - radius:
		return false
	if pos.y < OUTER_WALL + radius or pos.y > FLOOR_SIZE.y - OUTER_WALL - radius:
		return false
	for wall in WALLS:
		if (wall as Rect2).grow(radius).has_point(pos):
			return false
	return true


## Clamp a point inside the floor bounds (walls not considered).
## @param pos: Point to clamp.
## @param radius: Body radius.
## @returns: Clamped point.
static func clamp_to_floor(pos: Vector2, radius: float) -> Vector2:
	return Vector2(
		clampf(pos.x, OUTER_WALL + radius, FLOOR_SIZE.x - OUTER_WALL - radius),
		clampf(pos.y, OUTER_WALL + radius, FLOOR_SIZE.y - OUTER_WALL - radius))
