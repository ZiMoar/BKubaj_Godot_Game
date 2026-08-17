class_name AuraFieldVisual
extends Node2D

## Co-op: a remote visual-only copy of a teammate's Fire Aura. It follows that
## player's replica on this machine and pulses periodically so the field reads
## as alive, but deals no damage (the real aura on the firing machine already
## handles that against the shared enemy sim). Frees itself if the player goes
## down (ghost) or disappears.

var _target_name: String = ""
var _radius: float = 72.0
var _pulse: float = 0.0
var _pulse_timer: float = 0.0


## Configure from broadcast data (which player to follow, aura radius).
func setup_visual(data: Dictionary) -> void:
	_target_name = str(data.get("player_name", ""))
	_radius = float(data.get("radius", 72.0))
	queue_redraw()


func _physics_process(delta: float) -> void:
	var t: Node = NetworkManager.find_player_by_name(_target_name)
	if t is Node2D:
		if (t as Node).get("is_ghost") == true or float((t as Node).get("current_health")) <= 0.0:
			queue_free()
			return
		global_position = (t as Node2D).global_position
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = 0.4
		_pulse = 1.0
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	# Mirrors AuraVisual: soft translucent fill, inner molten glow, fire rings.
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.5, 0.15, 0.10 + 0.10 * _pulse))
	draw_circle(Vector2.ZERO, _radius * 0.6, Color(1.0, 0.7, 0.2, 0.06 + 0.08 * _pulse))
	var ring_alpha: float = 0.35 + 0.45 * _pulse
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(1.0, 0.45, 0.1, ring_alpha), 3.0)
	draw_arc(Vector2.ZERO, _radius * 0.8, 0.0, TAU, 48, Color(1.0, 0.8, 0.3, ring_alpha * 0.6), 2.0)
