class_name GridBackground
extends Node2D

@export var arena_size: Vector2 = Vector2(1920, 1080)
@export var grid_step: float = 64.0
@export var bg_color: Color = Color(0.14, 0.15, 0.19)
@export var grid_color: Color = Color(0.22, 0.24, 0.3, 0.7)
@export var border_color: Color = Color(0.4, 0.45, 0.55)

func _draw() -> void:
	# Draw main dark background fill
	draw_rect(Rect2(Vector2.ZERO, arena_size), bg_color)
	
	# Draw grid lines
	var x = 0.0
	while x <= arena_size.x:
		draw_line(Vector2(x, 0), Vector2(x, arena_size.y), grid_color, 1.0)
		x += grid_step
		
	var y = 0.0
	while y <= arena_size.y:
		draw_line(Vector2(0, y), Vector2(arena_size.x, y), grid_color, 1.0)
		y += grid_step
		
	# Outer arena border highlight
	draw_rect(Rect2(Vector2.ZERO, arena_size), border_color, false, 2.0)
