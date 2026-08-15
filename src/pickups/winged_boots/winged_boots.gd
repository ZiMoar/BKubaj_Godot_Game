class_name WingedBootsPickup
extends Area2D

## Winged Boots pickup. Walk over it to open a DashUpgradeMenu offering 1 of 3
## dash-only upgrades (+1 charge, faster recovery, longer dash). Placed by new
## room types / unique spawn conditions.

var _taken: bool = false

const BOOTS_COLOR: Color = Color(0.6, 0.8, 1.0)
const BOOTS_EDGE: Color = Color(0.3, 0.5, 0.8)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var r: float = 9.0
	draw_circle(Vector2.ZERO, r + 1.5, Color(0.6, 0.8, 1.0, 0.3))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, BOOTS_EDGE, 1.4)
	# Simple wing/boot glyph: two little wings flanking a boot-ish wedge.
	var wing: PackedVector2Array = PackedVector2Array([
		Vector2(-9, 0), Vector2(-3, 2), Vector2(-3, -2),
	])
	draw_colored_polygon(wing, BOOTS_COLOR)
	var wing2: PackedVector2Array = PackedVector2Array([
		Vector2(9, 0), Vector2(3, 2), Vector2(3, -2),
	])
	draw_colored_polygon(wing2, BOOTS_COLOR)
	draw_rect(Rect2(-3, -4, 6, 10), BOOTS_COLOR)


func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return
	# Only shows if the player actually has a dash-type mobility move (not the
	# mage's teleport, which doesn't use dash charges).
	if not body.has_method("get_class_ability_id"):
		return
	var ab_id: String = str(body.get_class_ability_id())
	if ab_id == "teleport" or ab_id.is_empty():
		return

	_taken = true
	var hud: HUD = get_tree().get_first_node_in_group("hud") as HUD
	if hud == null or not hud.has_method("show_dash_upgrade"):
		_taken = false
		return
	hud.show_dash_upgrade()
	queue_free()
