class_name Shopkeeper
extends Node2D

## Placeholder shopkeeper art (drawn in code; swap for a real sprite later).
## A hooded merchant silhouette behind a counter, with a gentle bob.

func _ready() -> void:
	queue_redraw()
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", 2.0, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", -2.0, 1.6).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	# Counter.
	draw_rect(Rect2(-30, 6, 60, 14), Color(0.45, 0.3, 0.18))
	draw_rect(Rect2(-30, 6, 60, 3), Color(0.6, 0.42, 0.24))
	# Hooded head.
	draw_circle(Vector2(0, -24), 12.0, Color(0.25, 0.18, 0.12))
	# Hood.
	draw_arc(Vector2(0, -24), 13.0, PI, TAU, 24, Color(0.32, 0.22, 0.14), 3.0)
	# Robe / body.
	var body := PackedVector2Array([
		Vector2(-16, -8), Vector2(16, -8), Vector2(20, 12), Vector2(-20, 12),
	])
	draw_colored_polygon(body, Color(0.32, 0.22, 0.14))
	# Cloak trim.
	draw_line(Vector2(0, -8), Vector2(0, 12), Color(0.85, 0.7, 0.3), 2.0)
	# Eyes (two small glints inside the hood).
	draw_circle(Vector2(-4, -25), 1.6, Color(1, 0.95, 0.7))
	draw_circle(Vector2(4, -25), 1.6, Color(1, 0.95, 0.7))
