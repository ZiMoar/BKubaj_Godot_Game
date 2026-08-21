class_name RadiusRing
extends Node2D

## A short-lived translucent ring that visualizes a damage radius (used by the
## Engineer's Rocket Jump blast and the Berserker's Whirlwind dash).

var radius: float = 80.0
var duration: float = 0.7
var ring_color: Color = Color(1.0, 0.4, 0.2, 0.6)

var _t: float = 0.0


func setup(r: float, dur: float, col: Color) -> void:
	radius = r
	duration = maxf(0.05, dur)
	ring_color = col


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(1.0 - _t / duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(ring_color.r, ring_color.g, ring_color.b, 0.12 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * fade), 2.5)
	draw_arc(Vector2.ZERO, radius * 0.85, 0.0, TAU, 40, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * fade * 0.5), 1.5)
