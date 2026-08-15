class_name HealPickup
extends Area2D

## Healing pickup. Collecting it restores a percentage of the player's max
## health. Three variants (25%, 50%, 100%) are defined as separate scenes that
## set `heal_fraction`. Dropped by new room types / unique spawn conditions.

## Fraction of max health restored on pickup (0.25 = 25%, 0.5 = 50%, 1.0 = full).
@export var heal_fraction: float = 0.25

var _collected: bool = false

const GREEN: Color = Color(0.35, 0.9, 0.5)
const GREEN_EDGE: Color = Color(0.15, 0.55, 0.3)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Pulse so it clearly reads as a pickup.
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var r: float = 7.0
	# Cross/heal glyph.
	draw_circle(Vector2.ZERO, r + 1.0, Color(0.35, 0.9, 0.5, 0.35))
	draw_circle(Vector2.ZERO, r, GREEN)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, GREEN_EDGE, 1.2)
	# Plus sign.
	draw_rect(Rect2(-2.0, -5.0, 4.0, 10.0), Color(1, 1, 1, 0.95))
	draw_rect(Rect2(-5.0, -2.0, 10.0, 4.0), Color(1, 1, 1, 0.95))


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	if body.has_method("roll_pickup_gluttony"):
		body.roll_pickup_gluttony()
	if body.has_method("heal_percent"):
		body.heal_percent(heal_fraction)
	queue_free()
