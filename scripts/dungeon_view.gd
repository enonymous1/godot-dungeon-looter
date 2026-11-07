## Draws the dungeon floor: dark stone tiles, walls, torches.
## Collision bodies live in main.gd; this node is visual only.
class_name DungeonView
extends Node2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Floor.
	draw_rect(Rect2(Vector2.ZERO, DungeonLogic.FLOOR_SIZE), Color(0.13, 0.12, 0.14))
	# Tile grid.
	var grid_color := Color(0.18, 0.17, 0.19)
	var x := 80.0
	while x < DungeonLogic.FLOOR_SIZE.x:
		draw_line(Vector2(x, 0), Vector2(x, DungeonLogic.FLOOR_SIZE.y), grid_color, 1.0)
		x += 80.0
	var y := 80.0
	while y < DungeonLogic.FLOOR_SIZE.y:
		draw_line(Vector2(0, y), Vector2(DungeonLogic.FLOOR_SIZE.x, y), grid_color, 1.0)
		y += 80.0
	# Outer walls.
	var wall_color := Color(0.05, 0.05, 0.07)
	var edge_color := Color(0.3, 0.28, 0.32)
	var w := DungeonLogic.OUTER_WALL
	var size := DungeonLogic.FLOOR_SIZE
	draw_rect(Rect2(0, 0, size.x, w), wall_color)
	draw_rect(Rect2(0, size.y - w, size.x, w), wall_color)
	draw_rect(Rect2(0, 0, w, size.y), wall_color)
	draw_rect(Rect2(size.x - w, 0, w, size.y), wall_color)
	draw_line(Vector2(w, w), Vector2(size.x - w, w), edge_color, 2.0)
	draw_line(Vector2(w, size.y - w), Vector2(size.x - w, size.y - w), edge_color, 2.0)
	# Interior walls.
	for wall in DungeonLogic.WALLS:
		var rect: Rect2 = wall
		draw_rect(rect, wall_color)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), edge_color, 2.0)
	# Torches: orange dot with a flickering glow.
	var t := Time.get_ticks_msec() / 1000.0
	for torch in DungeonLogic.TORCHES:
		var pos: Vector2 = torch
		var flicker := 0.75 + 0.25 * sin(t * 7.0 + pos.x)
		draw_circle(pos, 16.0 * flicker, Color(1.0, 0.6, 0.15, 0.18))
		draw_circle(pos, 6.0, Color(1.0, 0.65, 0.2))
