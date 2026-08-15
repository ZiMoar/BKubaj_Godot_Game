class_name RelicPedestal
extends Area2D

## A free relic offering in the middle of a RELIC room. Walk over it to open the
## Artefact choice menu. When the room spawns, a 10% roll decides this is a
## CURSED relic instead (offers only cursed relics from their own slot pool).

var _taken: bool = false
var _cursed: bool = false

const RELIC_COLOR: Color = Color(0.95, 0.78, 0.3)
const CURSE_COLOR: Color = Color(0.8, 0.2, 0.6)

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_cursed = rng.randf() < 0.10
	body_entered.connect(_on_body_entered)
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func _draw() -> void:
	var colour: Color = CURSE_COLOR if _cursed else RELIC_COLOR
	draw_circle(Vector2.ZERO, 16.0, Color(colour.r, colour.g, colour.b, 0.25))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, colour, 1.5)
	# Diamond body.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, -10), Vector2(9, 0), Vector2(0, 10), Vector2(-9, 0),
	])
	draw_colored_polygon(pts, colour)
	draw_polyline(pts, Color(1, 1, 1, 0.85), 1.2, true)


func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return

	_taken = true
	var hud: HUD = get_tree().get_first_node_in_group("hud") as HUD
	if hud == null or not hud.has_method("show_artefact_choice"):
		_taken = false
		return
	hud.show_artefact_choice(_cursed)
	queue_free()
