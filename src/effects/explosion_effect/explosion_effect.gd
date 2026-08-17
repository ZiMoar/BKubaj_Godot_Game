class_name ExplosionEffect
extends Node2D

## Short-lived visual for an explosion-on-kill: an expanding ring + flash that
## fades out, drawn with _draw() to match the project's grid aesthetic. It frees
## itself once the animation finishes.

@export var max_radius: float = 80.0
@export var color: Color = Color(1.0, 0.75, 0.2)

var _elapsed: float = 0.0
var _duration: float = 0.35


func _ready() -> void:
	z_index = 15
	queue_redraw()


## Co-op: configure a remote visual-only copy from broadcast data (used when a
## teammate's radiant barrier wave / explosion-on-kill should render here too).
func setup_visual(data: Dictionary) -> void:
	max_radius = float(data.get("max_radius", max_radius))
	color = data.get("color", color)
	_duration = float(data.get("_duration", _duration))
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var radius: float = max_radius * eased * 1.1

	# Outer ring (bright).
	var ring_alpha: float = 1.0 - progress
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, ring_alpha), 3.0)
	# Inner glow/flash (fills and fades faster).
	var glow_alpha: float = (1.0 - progress) * 0.5
	draw_circle(Vector2.ZERO, radius * 0.75, Color(color, glow_alpha))
