class_name Anvil
extends Area2D

## Anvil pickup. Like a treasure chest, but instead of granting a new weapon it
## opens the Anvil upgrade menu, letting the player boost stats on a weapon of
## their choice.

@onready var sprite: Node2D = $Visual

## Golden anvils (rare spawn) guarantee a signature upgrade in the choice menu.
var is_golden: bool = false

var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Make the visual reflect whether this is a golden (signature) anvil.
	if sprite and sprite.has_method("set"):
		sprite.set("golden", is_golden)
	# Subtle bob so the anvil clearly reads as a pickup.
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true

	var hud: HUD = get_tree().get_first_node_in_group("hud") as HUD
	if hud == null:
		var root: Node = get_tree().current_scene
		hud = root.get_node_or_null("HUD") as HUD

	if hud and hud.has_method("show_anvil_upgrade"):
		hud.show_anvil_upgrade(is_golden)
		queue_free()