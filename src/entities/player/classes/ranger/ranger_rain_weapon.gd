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
	# "+ projectile" anvil upgrades on the Longbow do two things: add arrows to
	# the Longbow's own volley (see bow_weapon.gd) AND scale the Rain's damage.
	# We read the raw projectile BONUS here — not the Longbow's effective arrow
	# count — so the Rain's damage doesn't fluctuate with which combo step the
	# Longbow is on; only the anvil bonus matters (+1 projectile => 2x, +2 => 3x).
	var proj_bonus: int = (bow.projectile_count_bonus if bow else projectile_count_bonus)
	if proj_bonus > 0:
		total = maxi(1, int(round(float(total) * float(1 + proj_bonus))))
	var eff_radius: float = radius * area_mult

	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		var enemy: Node2D = node as Node2D
		if enemy.global_position.distance_to(center) <= eff_radius:
			# Inherit the Longbow's element too, so infusing the bow changes the rain.
			var dmg_type: DamageType.Type = (bow.damage_type if bow else damage_type)
			enemy.take_damage(total, false, dmg_type, false, get_ailment_effect_multiplier())
			apply_lifesteal()
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(center, get_knockback(220.0))
			if enemy.is_in_group("enemies"):
				if enemy.has_method("has_died") and enemy.has_died():
					if bow:
						bow.apply_explosion_on_kill(enemy.global_position, total)
					else:
						apply_explosion_on_kill(enemy.global_position, total)

	if rain_visual_scene:
		var visual = rain_visual_scene.instantiate()
		visual.global_position = center
		if visual.has_method("setup"):
			visual.setup(eff_radius)
		get_tree().current_scene.add_child(visual)
		var net: Node = get_node_or_null("/root/Net")
		if net and net.has_method("sync_player_effect"):
			net.sync_player_effect(visual, rain_visual_scene, {"radius": eff_radius})
