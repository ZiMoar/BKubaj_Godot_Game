class_name AuraVisual
extends Node2D

@export var aura_radius: float = 72.0

var _pulse: float = 0.0  # 0..1 flash intensity, decays over time


func _ready() -> void:
	queue_redraw()


func set_radius(radius: float) -> void:
	aura_radius = radius
	queue_redraw()


func pulse() -> void:
	_pulse = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	# Soft translucent fill marking the aura's damage area
	draw_circle(Vector2.ZERO, aura_radius, Color(1.0, 0.5, 0.15, 0.10 + 0.10 * _pulse))
	# Inner molten glow
	draw_circle(Vector2.ZERO, aura_radius * 0.6, Color(1.0, 0.7, 0.2, 0.06 + 0.08 * _pulse))

	# Outer fire ring
	var ring_alpha: float = 0.35 + 0.45 * _pulse
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 48, Color(1.0, 0.45, 0.1, ring_alpha), 3.0)
	# Lighter inner ring
	draw_arc(Vector2.ZERO, aura_radius * 0.8, 0.0, TAU, 48, Color(1.0, 0.8, 0.3, ring_alpha * 0.6), 2.0)