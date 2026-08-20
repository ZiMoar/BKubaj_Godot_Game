class_name AltarPedestal
extends Area2D

## The Altar of Ascension offering in the middle of the altar room. Walk over it
## to open the Subclass choice menu (the 3 ascensions for your current class).

var _taken: bool = false

const ALTAR_COLOR: Color = Color(0.6, 0.4, 0.95)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func _draw() -> void:
	# Ground platform.
	var platform: PackedVector2Array = PackedVector2Array([
		Vector2(-26, 10), Vector2(26, 10), Vector2(18, 18), Vector2(-18, 18),
	])
	draw_colored_polygon(platform, Color(ALTAR_COLOR.r, ALTAR_COLOR.g, ALTAR_COLOR.b, 0.9))
	# Soft glow ring (bigger and brighter than before so it reads at a glance).
	draw_circle(Vector2.ZERO, 30.0, Color(ALTAR_COLOR.r, ALTAR_COLOR.g, ALTAR_COLOR.b, 0.20))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color(ALTAR_COLOR.r, ALTAR_COLOR.g, ALTAR_COLOR.b, 0.95), 2.0)
	# Ascension glyph: a stepped pyramid.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, -22), Vector2(18, 10), Vector2(-18, 10),
	])
	draw_colored_polygon(pts, ALTAR_COLOR)
	draw_polyline(pts, Color(1, 1, 1, 0.9), 1.4, true)
	pts = PackedVector2Array([
		Vector2(-18, 10), Vector2(-11, 18), Vector2(11, 18), Vector2(18, 10),
	])
	draw_polyline(pts, ALTAR_COLOR, 2.0, true)


func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return

	_taken = true
	var hud: HUD = get_tree().get_first_node_in_group("hud") as HUD
	if hud == null or not hud.has_method("show_subclass_choice"):
		_taken = false
		return
	hud.show_subclass_choice()
	queue_free()
