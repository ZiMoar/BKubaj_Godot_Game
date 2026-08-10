class_name TreasureChest
extends Node2D

@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D

var _collected: bool = false


func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)
	# Add a subtle bob animation
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

	# Find the HUD and show the weapon choice menu
	var hud: HUD = get_tree().get_first_node_in_group("hud") as HUD
	if hud == null:
		# Try finding it the old way
		var root: Node = get_tree().current_scene
		hud = root.get_node_or_null("HUD") as HUD

	if hud and hud.has_method("show_weapon_choice"):
		hud.show_weapon_choice()
		queue_free()
