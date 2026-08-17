class_name BossTelegraph
extends Node2D

## Procedurally drawn telegraph markers for boss attacks (warning zones).
## Sub-classes / bosses call show_circle / show_line to display a warning
## before an attack resolves, then hide_telegraph() to clear it.

enum Mode { NONE, CIRCLE, LINE }

var mode: int = Mode.NONE
var zone_radius: float = 0.0
var zone_color: Color = Color(1, 0.25, 0.25, 0.35)
var line_length: float = 0.0
var line_color: Color = Color(1, 0.6, 0.2, 0.5)
var line_width: float = 6.0
var aim_direction: Vector2 = Vector2.RIGHT


func _draw() -> void:
	match mode:
		Mode.CIRCLE:
			draw_circle(Vector2.ZERO, zone_radius, zone_color)
			draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 48, Color(zone_color, 1.0), 3.0)
		Mode.LINE:
			draw_line(Vector2.ZERO, aim_direction.normalized() * line_length, line_color, line_width)


func show_circle(radius: float, color: Color = Color(1, 0.25, 0.25, 0.35)) -> void:
	mode = Mode.CIRCLE
	zone_radius = radius
	zone_color = color
	show()
	queue_redraw()


func show_line(length: float, direction: Vector2, color: Color = Color(1, 0.6, 0.2, 0.5)) -> void:
	mode = Mode.LINE
	line_length = length
	aim_direction = direction.normalized()
	line_color = color
	show()
	queue_redraw()


func hide_telegraph() -> void:
	mode = Mode.NONE
	hide()
	queue_redraw()


## In co-op the telegraph is a child of the host-simulated boss. The host's
## MultiplayerSynchronizer replicates this node's state (mode / radii / colors /
## direction / visibility), but replication alone doesn't re-render it — so on a
## client replica we redraw every frame to reflect the latest replicated values.
## (Hidden nodes skip drawing, so this is a no-op while the telegraph is off.)
func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		return
	queue_redraw()