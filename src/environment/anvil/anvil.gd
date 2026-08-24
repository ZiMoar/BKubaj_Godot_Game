class_name Anvil
extends Area2D

## Anvil pickup. Like a treasure chest, but instead of granting a new weapon it
## opens the Anvil upgrade menu, letting the player boost stats on a weapon of
## their choice.

@onready var sprite: Node2D = $Visual

## Golden anvils (rare spawn) guarantee a signature upgrade in the choice menu.
var is_golden: bool = false

## Anvil kind passed to the upgrade menu: 0=standard, 1=elemental, 2=inverted.
## Elemental anvils reforge damage types; inverted anvils trade away stats. The
## standard pickup (anvil.tscn) is kind 0; elemental/inverted are distinct room
## spawns set from their own scene/spawner.
var anvil_kind: int = 0

var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Make the visual reflect golden and/or kind.
	if sprite and sprite.has_method("set"):
		sprite.set("golden", is_golden)
		sprite.set("kind", anvil_kind)
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
		# Smith's Hammer relic: a 10% chance the anvil isn't consumed and can be
		# used again. Defer the free decision until the upgrade menu closes.
		var reuse: bool = body.has_method("has_artefact") and body.has_artefact("smiths_hammer") \
			and randf() < 0.10
		if reuse and hud.has_method("anvil_upgrade_menu") and hud.anvil_upgrade_menu != null:
			hud.anvil_upgrade_menu.menu_closed.connect(_on_menu_closed, CONNECT_ONE_SHOT)
		hud.show_anvil_upgrade(is_golden, anvil_kind)
		if not reuse:
			queue_free()


## Smith's Hammer relic: the anvil was not consumed. Reusable the next time the
## player walks onto it (must leave and re-enter to re-trigger).
func _on_menu_closed() -> void:
	_collected = false