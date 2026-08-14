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


## The Longbow is this weapon's upgrade source: the rain inherits the bow's
## anvil stats (damage, area, crit, status, explosion) so upgrading the primary
## weapon also strengthens the secondary.
func _bow_weapon() -> Weapon:
	var p = get_player()
	if p == null:
		return null
	var container: Node = p.get_node_or_null("Weapons")
	if container == null:
		return null
	for w: Node in container.get_children():
		if w is Weapon and w != self and w.weapon_name == "Longbow":
			return w as Weapon
	return null


func fire() -> void:
	var center: Vector2 = get_global_mouse_position()
	var bow: Weapon = _bow_weapon()
	# Delegate stat computation to the bow so its anvil upgrades apply here too.
	var area_mult: float = bow.get_area_multiplier() if bow else get_area_multiplier()
	var total: int = (bow.get_attack_damage(damage) if bow else get_attack_damage(damage))
	var is_critical: bool = (bow.roll_critical_hit() if bow else roll_critical_hit())
	if is_critical:
		var crit_mult: float = bow.get_critical_multiplier() if bow else get_critical_multiplier()
		total = int(round(float(total) * crit_mult))
	var eff_radius: float = radius * area_mult

	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		var enemy: Node2D = node as Node2D
		if enemy.global_position.distance_to(center) <= eff_radius:
			enemy.take_damage(total)
			apply_lifesteal()
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(center, 220.0)
			if enemy.is_in_group("enemies"):
				(bow.apply_status_on_hit(enemy, total) if bow else apply_status_on_hit(enemy, total))
				if enemy.has_method("has_died") and enemy.has_died():
					(bow.apply_explosion_on_kill(enemy.global_position, total) if bow else apply_explosion_on_kill(enemy.global_position, total))

	if rain_visual_scene:
		var visual = rain_visual_scene.instantiate()
		visual.global_position = center
		if visual.has_method("setup"):
			visual.setup(eff_radius)
		get_tree().current_scene.add_child(visual)
