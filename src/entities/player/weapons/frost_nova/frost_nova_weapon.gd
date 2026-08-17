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
	damage_type = DamageType.Type.COLD
	super._ready()
	call_deferred("try_fire")

func supports_range_damage() -> bool:
	return true


## Frost Nova's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "deep_freeze",
			"title": "Deep Freeze",
			"description": "Slowed enemies may become frozen, stopping them and doubling damage taken.",
			"value": 35,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


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
	# Deep Freeze: an enemy that was ALREADY slowed has a chance to be frozen solid.
	var deep_freeze_owned: bool = has_signature("deep_freeze")
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= eff_radius:
			# Whether the target was already slowed BEFORE this nova's slow hits.
			var was_slowed: bool = en.get("slow_timer") != null and float(en.get("slow_timer")) > 0.0
			en.take_damage(dmg, false, damage_type, false, get_ailment_effect_multiplier())
			apply_lifesteal()
			if en.has_method("apply_slow"):
				en.apply_slow(slow_duration, slow_factor)
			# Freeze only if it was already slowed (so the first slow never
			# freezes), and only at the signature's chance.
			if deep_freeze_owned and was_slowed and en.has_method("apply_freeze") and randf() < 0.35:
				en.apply_freeze()
			if en.is_in_group("enemies"):
				if en.has_method("has_died") and en.has_died():
					apply_explosion_on_kill(en.global_position, dmg)

	if frost_scene:
		var ring = frost_scene.instantiate()
		if ring != null and ring.has_method("setup"):
			ring.global_position = origin
			ring.setup(eff_radius)
			get_tree().current_scene.add_child(ring)
			var net: Node = get_node_or_null("/root/Net")
			if net and net.has_method("sync_player_effect"):
				net.sync_player_effect(ring, frost_scene, {"radius": eff_radius})
