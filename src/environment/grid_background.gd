class_name GridBackground
extends Node2D

## Center of the arena floor. The grid is drawn symmetrically around this point,
## so a map can be any size/orientation (landscape or portrait) and still tile its
## floor directly under its walls.
@export var arena_center: Vector2 = Vector2(960, 540)
@export var arena_size: Vector2 = Vector2(1920, 1080)
@export var grid_step: float = 64.0
@export var bg_color: Color = Color(0.14, 0.15, 0.19)
@export var grid_color: Color = Color(0.22, 0.24, 0.3, 0.7)
@export var border_color: Color = Color(0.4, 0.45, 0.55)

func _draw() -> void:
	var top_left := arena_center - arena_size * 0.5
	# Draw main dark background fill
	draw_rect(Rect2(top_left, arena_size), bg_color)

	# Draw grid lines
	var x := top_left.x
	while x <= top_left.x + arena_size.x:
		draw_line(Vector2(x, top_left.y), Vector2(x, top_left.y + arena_size.y), grid_color, 1.0)
		x += grid_step

	var y := top_left.y
	while y <= top_left.y + arena_size.y:
		draw_line(Vector2(top_left.x, y), Vector2(top_left.x + arena_size.x, y), grid_color, 1.0)
		y += grid_step

	# Outer arena border highlight
	draw_rect(Rect2(top_left, arena_size), border_color, false, 2.0)
