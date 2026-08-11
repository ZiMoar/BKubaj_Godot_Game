class_name FrostRing
extends Node2D

## A single expanding, fading frost ring drawn at a position. Purely visual
## feedback for the Frost Nova weapon.

var radius: float = 210.0
var _life: float = 0.5


func setup(r: float) -> void:
	radius = maxf(20.0, r)
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a: float = clampf(_life / 0.5, 0.0, 1.0)
	var r: float = radius * (1.0 + (1.0 - a) * 0.35)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.5, 0.85, 1.0, a * 0.7), 3.0)
	draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 32, Color(0.75, 0.95, 1.0, a * 0.5), 2.0)
