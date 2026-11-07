## A loot drop lying on the dungeon floor: a rarity-colored diamond
## with the item name above it. The main scene picks it up when the
## player walks onto it after clicking it.
## Call setup() BEFORE adding the node to the tree: the name label
## is built in _ready from `item`, so a late setup would leave the
## label saying "Item".
class_name LootDrop
extends Node2D

const BOB_INTERVAL := 0.066

var item: Dictionary = {}

var _bob := 0.0
var _redraw_timer := 0.0


func setup(p_item: Dictionary, pos: Vector2) -> void:
	item = p_item.duplicate(true)
	global_position = pos


func _ready() -> void:
	var label := Label.new()
	label.text = String(item.get("name", "Item"))
	label.add_theme_color_override("font_color", LootLogic.rarity_color(int(item.get("rarity", 0))))
	label.position = Vector2(-48, -36)
	label.z_index = 10
	add_child(label)


func _process(delta: float) -> void:
	# The bob is a slow sine, so 15 Hz redraws are indistinguishable
	# from every frame and cost a fraction of the draw calls.
	_bob += delta
	_redraw_timer += delta
	if _redraw_timer >= BOB_INTERVAL:
		_redraw_timer = 0.0
		queue_redraw()


func _draw() -> void:
	var color: Color = LootLogic.rarity_color(int(item.get("rarity", 0)))
	var bob_y := sin(_bob * 3.0) * 3.0
	var center := Vector2(0, bob_y)
	var points := PackedVector2Array([
		center + Vector2(0, -10), center + Vector2(8, 0),
		center + Vector2(0, 10), center + Vector2(-8, 0)])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.05, 0.05, 0.05), 1.5)
	draw_circle(center + Vector2(0, 12), 8.0, Color(0, 0, 0, 0.25))
