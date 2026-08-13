extends Weapon

## Frost Nova — automatic. Every cooldown, blasts everything in a radius around
## the player, damaging it and briefly slowing it. A drawn ring shows the effect.

@export var nova_radius: float = 105.0
@export var base_damage: int = 42
@export var slow_duration: float = 2.0
@export var slow_factor: float = 0.45
@export var frost_scene: PackedScene


func _ready() -> void:
	weapon_name = "Frost Nova"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 3.0
	super._ready()
	call_deferred("try_fire")

func supports_range_damage() -> bool:
	return true


func fire() -> void:
	var origin: Vector2 = global_position
	var eff_radius: float = nova_radius * get_area_multiplier()
	var dmg: int = get_attack_damage(base_damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		targets.append(d)
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= eff_radius:
			en.take_damage(dmg)
			apply_lifesteal()
			if en.has_method("apply_slow"):
				en.apply_slow(slow_duration, slow_factor)
			if en.is_in_group("enemies"):
				apply_status_on_hit(en, dmg)
				if en.has_method("has_died") and en.has_died():
					apply_explosion_on_kill(origin, dmg)

	if frost_scene:
		var ring = frost_scene.instantiate()
		if ring != null and ring.has_method("setup"):
			ring.global_position = origin
			ring.setup(eff_radius)
			get_tree().current_scene.add_child(ring)
