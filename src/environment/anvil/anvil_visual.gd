extends Node2D

## Draws a simple top-down anvil shape (grey metal body + darker base) using
## _draw(), so the pickup is visible without needing a sprite asset.

func _draw() -> void:
	# Base block (the anvil's flat bottom)
	draw_rect(Rect2(-14, 6, 28, 8), Color(0.35, 0.35, 0.4))

	# Main spike/horn tapering up
	var horn := PackedVector2Array([
		Vector2(-13, 6),
		Vector2(-6, -6),
		Vector2(6, -6),
		Vector2(13, 6),
	])
	draw_colored_polygon(horn, Color(0.55, 0.55, 0.62))

	# Top bar of the anvil
	draw_rect(Rect2(-16, -8, 32, 5), Color(0.6, 0.6, 0.68))

	# Lighter highlight for readability
	draw_rect(Rect2(-6, -3, 12, 3), Color(0.75, 0.75, 0.82))