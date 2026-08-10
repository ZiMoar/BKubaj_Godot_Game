extends Weapon

## Ranger secondary ability: a Rain of Arrows. Currently this simply applies
## area damage inside a circle centred on the player's cursor. The actual
## "arrows raining down" animation is planned for later.
@export var damage: int = 34
@export var radius: float = 150.0
@export var rain_visual_scene: PackedScene


func _ready() -> void:
	weapon_name = "Rain of Arrows"
	trigger_type = TriggerType.SECONDARY
	cooldown = 4.0
	super._ready()


func fire() -> void:
	var center: Vector2 = get_global_mouse_position()
	var eff_radius: float = radius * get_area_multiplier()
	var total: int = get_attack_damage(damage)
	var is_critical: bool = roll_critical_hit()
	if is_critical:
		total = int(round(float(total) * get_critical_multiplier()))

	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		var enemy: Node2D = node as Node2D
		if enemy.global_position.distance_to(center) <= eff_radius:
			enemy.take_damage(total)
			apply_lifesteal()
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(center, 220.0)

	if rain_visual_scene:
		var visual = rain_visual_scene.instantiate()
		visual.global_position = center
		if visual.has_method("setup"):
			visual.setup(eff_radius)
		get_tree().current_scene.add_child(visual)
