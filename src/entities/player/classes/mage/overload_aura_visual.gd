class_name OverloadAuraVisual
extends Node2D

## Co-op: a remote visual-only copy of a teammate's Mana Overload buff aura. It
## follows that player's replica for the buff's duration, pulsing, then frees
## itself. Purely cosmetic — the real buff's cooldown halving happens on the
## firing machine's own player.

var _target_name: String = ""
var _life: float = 4.0


## Configure from broadcast data (which player to follow, buff duration).
func setup_visual(data: Dictionary) -> void:
	_target_name = str(data.get("player_name", ""))
	_life = float(data.get("life", 4.0))
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var t: Node = NetworkManager.find_player_by_name(_target_name)
	if t is Node2D:
		global_position = (t as Node2D).global_position
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var r: float = 42.0 * (1.0 + 0.10 * pulse)
	draw_circle(Vector2.ZERO, r * 0.7, Color(0.45, 0.3, 0.9, 0.30 + 0.14 * pulse))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.55, 0.4, 1.0, 0.85 + 0.15 * pulse), 3.0)
	draw_arc(Vector2.ZERO, r * 0.85, 0.0, TAU, 40, Color(0.7, 0.55, 1.0, 0.5), 2.0)
