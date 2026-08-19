class_name DestructibleBase
extends ObstacleBase

## A breakable map obstacle. Blocks movement (layer 1) just like an obstacle,
## but has hit points and can be destroyed by the player's weapons. On
## destruction it drops a little loot and triggers a subclass effect.

@export var max_health: int = 40
@export var loot_gold: int = 1  # number of gold coins dropped on destruction

var current_health: int
var _cracked := false

const GOLD_SCENE: PackedScene = preload("res://src/pickups/gold_pickup/gold_pickup.tscn")

func _ready() -> void:
	super._ready()
	current_health = max_health
	add_to_group("destructibles")

# Matches the player-weapon damage contract used on enemies
# (take_damage(amount, is_critical, damage_type, suppress_ailment,
# ailment_multiplier)). Destructibles ignore the elemental/ailment params — they
# exist so a single weapon/projectile call site can hit enemies AND destructibles
# without a "Expected N argument(s)" runtime error. (CrumblingPillar etc. are in
# the "destructibles" group and are damaged by area weapons with the full enemy
# signature, e.g. explosive_charge, magic_bolt, aura.)
func take_damage(amount: int, _is_critical: bool = false, _damage_type: int = 0, _suppress_ailment: bool = false, _ailment_multiplier: float = 1.0) -> void:
	current_health -= amount
	queue_redraw()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.35, 1.35, 1.35), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	if current_health <= 0:
		_destroy()
	else:
		_cracked = current_health <= int(round(float(max_health) * 0.5))
		queue_redraw()

func _destroy() -> void:
	_drop_loot()
	_effect_on_destroy()
	queue_free()

func _drop_loot() -> void:
	for i in range(loot_gold):
		var coin := GOLD_SCENE.instantiate()
		if coin == null:
			continue
		coin.global_position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		coin.setup(2)
		get_tree().current_scene.call_deferred("add_child", coin)

# Optional subclass effect that fires when the destructible is destroyed.
func _effect_on_destroy() -> void:
	pass
