class_name Pillar
extends ObstacleBase

## A solid stone pillar. Pure obstacle — blocks movement, cannot be destroyed.

@export var size: float = 30.0
@export var body_color: Color = Color(0.5, 0.52, 0.56)
@export var cap_color: Color = Color(0.62, 0.64, 0.68)

func _draw() -> void:
	var half := size * 0.5
	# Drop shadow
	draw_rect(Rect2(-half + 2.0, -half + 4.0, size, size), Color(0, 0, 0, 0.3))
	# Column body
	draw_rect(Rect2(-half, -half, size, size), body_color)
	# Left highlight
	draw_rect(Rect2(-half, -half, 4.0, size), Color(1, 1, 1, 0.14))
	# Right shadow
	draw_rect(Rect2(half - 4.0, -half, 4.0, size), Color(0, 0, 0, 0.22))
	# Top cap (raised, lighter)
	draw_rect(Rect2(-half - 2.0, -half - 4.0, size + 4.0, 5.0), cap_color)
	draw_rect(Rect2(-half - 2.0, -half - 4.0, 4.0, 5.0), cap_color.lightened(0.12))