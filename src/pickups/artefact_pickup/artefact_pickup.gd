class_name ArtefactPickup
extends Area2D

## A boss relic drop. When the player walks over it, an ArtefactChoiceMenu
## opens offering a choice of 3 random artefacts (with their descriptions).
## If all 5 slots are full, the relic is refused. Setting `cursed` makes this a
## cursed relic (offers only cursed relics from their own slot pool, in purple).

var _taken: bool = false

const RELIC_COLOR: Color = Color(0.95, 0.78, 0.3)
const CURSE_COLOR: Color = Color(0.8, 0.2, 0.6)

## When true, this pickup opens a CURSED artefact choice and is tinted purple.
@export var cursed: bool = false

@onready var name_label: Label = get_node_or_null("NameLabel") as Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_set_visual()


func _pickup_color() -> Color:
	return CURSE_COLOR if cursed else RELIC_COLOR


func _set_visual() -> void:
	var c: Color = _pickup_color()
	modulate = c
	if name_label:
		name_label.text = "Cursed Relic" if cursed else "Relic"
		name_label.add_theme_color_override("font_color", c.lightened(0.25))
	queue_redraw()


func _draw() -> void:
	var c: Color = _pickup_color()
	# Outer glow ring.
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, c, 1.5)
	# Diamond body.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0),
	])
	draw_colored_polygon(pts, c)
	# Cursed relics get a jagged red-tipped edge instead of the clean white line.
	var edge: Color = Color(1, 0.4, 0.4, 0.9) if cursed else Color(1, 1, 1, 0.85)
	draw_polyline(pts, edge, 1.2, true)


func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("get_artefact_count") or not body.has_method("get_artefact_slot_capacity"):
		return

	if body.get_artefact_count() >= body.get_artefact_slot_capacity():
		_flash_refusal()
		return

	_taken = true
	var hud: HUD = get_tree().get_first_node_in_group("hud") as HUD
	if hud == null or not hud.has_method("show_artefact_choice"):
		_taken = false
		return
	hud.show_artefact_choice(cursed)
	queue_free()


func _flash_refusal() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.3, 0.15)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
