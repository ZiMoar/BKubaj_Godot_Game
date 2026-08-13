class_name CrumblingPillar
extends DestructibleBase

## A weathered, cracked pillar that blocks movement until the player breaks it
## apart. Shows increasing cracks as it takes damage, then crumbles away and
## drops a bit of gold.

@export var size: float = 30.0
@export var stone_color: Color = Color(0.46, 0.48, 0.52)

func _draw() -> void:
	var half := size * 0.5
	# Drop shadow
	draw_rect(Rect2(-half + 2.0, -half + 4.0, size, size), Color(0, 0, 0, 0.3))
	# Column body
	draw_rect(Rect2(-half, -half, size, size), stone_color)
	# Left highlight
	draw_rect(Rect2(-half, -half, 4.0, size), Color(1, 1, 1, 0.14))
	# Right shadow
	draw_rect(Rect2(half - 4.0, -half, 4.0, size), Color(0, 0, 0, 0.22))
	# Top cap
	draw_rect(Rect2(-half - 2.0, -half - 4.0, size + 4.0, 5.0), stone_color.lightened(0.12))

	if _cracked:
		# X-shaped cracks across the pillar.
		draw_line(Vector2(-half * 0.5, -half * 0.3), Vector2(half * 0.3, half * 0.5), Color(0, 0, 0, 0.55), 1.5)
		draw_line(Vector2(half * 0.4, -half * 0.4), Vector2(-half * 0.4, half * 0.4), Color(0, 0, 0, 0.55), 1.5)