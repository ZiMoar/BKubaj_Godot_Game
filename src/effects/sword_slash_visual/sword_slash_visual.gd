class_name SwordSlashVisual
extends Node2D

## Co-op: a standalone visual replica of a teammate's melee swing, drawn for a
## fraction of a second and faded out. Purely cosmetic — the real swing's damage
## is already handled on the firing machine through the host-authoritative enemy
## pipeline, so this just lets the other player SEE the swing.

var _pts: PackedVector2Array = PackedVector2Array()
var _color: Color = Color.WHITE
var _life: float = 0.15


## Configure from broadcast data (reach, combo shape, color). Called on the
## remote machine by the effect-sync helper.
func setup_visual(data: Dictionary) -> void:
	var reach: float = float(data.get("reach", 100.0))
	var color: Color = data.get("color", Color.WHITE)
	_color = color
	var is_stab: bool = bool(data.get("is_stab", false))
	if is_stab:
		_pts = PackedVector2Array([
			Vector2(0, -12),
			Vector2(0, 12),
			Vector2(reach, 0),
		])
	else:
		var span: float = deg_to_rad(float(data.get("angle_deg", 100.0)))
		var half: float = span * 0.5
		var segments: int = maxi(3, int(data.get("segments", 16)))
		_pts = PackedVector2Array([Vector2.ZERO])
		for i in range(segments + 1):
			var a: float = -half + span * float(i) / float(segments)
			_pts.append(Vector2(reach * cos(a), reach * sin(a)))
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _pts.size() < 2:
		return
	var fade: float = clampf(_life / 0.15, 0.0, 1.0)
	var col: Color = Color(_color.r, _color.g, _color.b, _color.a * fade)
	draw_colored_polygon(_pts, col)
	draw_polyline(_pts, Color(1, 1, 1, 0.8 * fade), 1.5)
