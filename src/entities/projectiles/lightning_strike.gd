class_name LightningStrike
extends Node2D

## A short-lived jagged lightning poly-line used as feedback for the chain
## Lightning weapon. Draws between the given (local) points and fades out.

var points: PackedVector2Array = PackedVector2Array()
var color: Color = Color(1.0, 0.9, 0.3, 1.0)
var _fade: float = 1.0
var _life: float = 0.35


func setup(poly: PackedVector2Array, col: Color = Color(1.0, 0.9, 0.3, 1.0)) -> void:
	points = poly
	color = col
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	_fade = clampf(_life / 0.35, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var pts := PackedVector2Array()
	for i in range(points.size()):
		var p := points[i]
		if i > 0 and i < points.size() - 1:
			p += Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		pts.append(p)
	var col := Color(color.r, color.g, color.b, color.a * _fade)
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], col, 3.0)
	# Small bright core
	if pts.size() >= 2:
		draw_line(pts[0], pts[pts.size() - 1], Color(1, 1, 1, _fade * 0.8), 1.5)
