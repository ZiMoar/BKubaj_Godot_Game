extends Node2D

## Draws a simple top-down anvil shape (grey metal body + darker base) using
## _draw(), so the pickup is visible without needing a sprite asset. Golden
## anvils (rare) are drawn in warm gold to telegraph they grant signatures.

## Golden color scheme for the 5% signature-granting anvil.
@export var golden: bool = false:
	set(v):
		golden = v
		queue_redraw()

func _draw() -> void:
	var body := Color(0.55, 0.55, 0.62)
	var base := Color(0.35, 0.35, 0.4)
	var bar := Color(0.6, 0.6, 0.68)
	var hilite := Color(0.75, 0.75, 0.82)
	if golden:
		body = Color(0.95, 0.72, 0.22)
		base = Color(0.6, 0.42, 0.1)
		bar = Color(0.98, 0.82, 0.4)
		hilite = Color(1.0, 0.92, 0.6)

	# Base block (the anvil's flat bottom)
	draw_rect(Rect2(-14, 6, 28, 8), base)

	# Main spike/horn tapering up
	var horn := PackedVector2Array([
		Vector2(-13, 6),
		Vector2(-6, -6),
		Vector2(6, -6),
		Vector2(13, 6),
	])
	draw_colored_polygon(horn, body)

	# Top bar of the anvil
	draw_rect(Rect2(-16, -8, 32, 5), bar)

	# Lighter highlight for readability
	draw_rect(Rect2(-6, -3, 12, 3), hilite)