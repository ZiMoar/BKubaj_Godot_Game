extends Weapon

## Magic Pulse — automatic. Fires a cone of arcane energy toward the nearest
## enemy, dealing ARCANE damage to everything in the cone and pushing it back.
## Projectile count fires multiple parallel cones.

const MagicPulseScene: PackedScene = preload("res://src/entities/projectiles/magic_pulse/magic_pulse.tscn")

const BASE_PULSE_COUNT: int = 1
const BASE_DAMAGE: int = 38
const PULSE_RANGE: float = 210.0
const PULSE_KNOCKBACK: float = 260.0
const COOLDOWN: float = 2.2


func _ready() -> void:
	weapon_name = "Magic Pulse"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.ARCANE
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_area() -> bool:
	return true


## Magic Pulse's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "vacuum_grasp",
			"title": "Vacuum Grasp",
			"description": "Pulses now PULL enemies toward the impact point instead of knocking them away, grouping them up.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	var count: int = get_effective_projectile_count(BASE_PULSE_COUNT)
	var aim: Vector2 = _nearest_enemy_dir()
	var dmg: int = get_attack_damage(BASE_DAMAGE)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	# Spread parallel cones slightly on multi-cast.
	var spread: float = 0.16
	for i in range(count):
		var offset: float = (float(i) - float(count - 1) * 0.5) * spread
		var cone_dir: Vector2 = aim.rotated(offset)
		var pulse: Node = MagicPulseScene.instantiate()
		pulse.name = "MagicPulse"
		pulse.global_position = global_position
		if pulse.has_method("setup"):
			pulse.setup(self, get_player(), cone_dir, dmg, crit, PULSE_RANGE * get_area_multiplier(), PULSE_KNOCKBACK)
		get_tree().current_scene.add_child(pulse)


func _nearest_enemy_dir() -> Vector2:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var best_d: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			nearest = en
	if nearest != null:
		return (nearest.global_position - global_position).normalized()
	return Vector2.RIGHT
