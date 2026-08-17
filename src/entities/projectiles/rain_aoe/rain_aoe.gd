class_name RainAoE
extends Node2D

## Temporary circular visual for the Ranger's Rain of Arrows. Actual "arrows
## falling" animation will replace this once proper animations exist. It only
## draws a fading ring to telegraph the area that was struck.
var _life: float = 0.45
var radius: float = 150.0


func setup(circle_radius: float) -> void:
	radius = circle_radius


## Co-op: configure a remote visual-only copy from broadcast data.
func setup_visual(data: Dictionary) -> void:
	setup(float(data.get("radius", 150.0)))


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _life <= 0.0:
		return
	var alpha: float = clampf((_life / 0.45), 0.0, 1.0)
	# Filled hit zone fading out + a bright rim.
	draw_circle(Vector2.ZERO, radius, Color(0.65, 0.8, 0.3, 0.28 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.85, 1.0, 0.4, 0.8 * alpha), 3.0, true)
