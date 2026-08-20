extends Weapon

## Chromatic Bolt — automatic. Throws an orb that decelerates and comes to rest,
## then lingers; while it's alive it fires bolts of RANDOM damage type at nearby
## enemies. The orb itself deals no damage and passes through enemies. Projectile
## count raises the number of BOLTS per volley (not the number of orbs).

const ChromaticOrbScene: PackedScene = preload("res://src/entities/projectiles/chromatic_orb/chromatic_orb.tscn")

const ORB_INITIAL_SPEED: float = 130.0
const ORB_DECEL: float = 19.0
const ORB_LIFETIME: float = 10.0
const BOLT_INTERVAL: float = 0.6
const BASE_BOLT_COUNT: int = 3
const BASE_BOLT_DAMAGE: int = 30
const COOLDOWN: float = 4.0


func _ready() -> void:
	weapon_name = "Chromatic Bolt"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.CHROMATIC  # signals random element; the bolts randomize per hit
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

func supports_duration() -> bool:
	return true

func supports_chain() -> bool:
	return true


## Chromatic Bolt's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "ailment_resonance",
			"title": "Ailment Resonance",
			"description": "Bolts deal +20% damage for each distinct ailment on the enemy.",
			"value": 20,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	# Aim the throw at the nearest enemy, else a random direction.
	var dir_start: Vector2 = _aim_direction()

	# +Projectile scales the NUMBER OF ORBS thrown (the base projectile), not the
	# number of bonus bolts per orb — bolt count stays fixed at its base.
	var orb_count: int = get_effective_projectile_count(1)
	# Fan the throw directions so multiple orbs spread out instead of stacking.
	var spread_deg: float = 14.0
	for i in range(orb_count):
		var t: float = 0.0
		if orb_count > 1:
			t = float(i) / float(orb_count - 1)
		var ang: float = deg_to_rad(-spread_deg / 2.0) + deg_to_rad(spread_deg) * t
		var orb_dir: Vector2 = dir_start.rotated(ang)

		var orb: Node = ChromaticOrbScene.instantiate()
		orb.name = "ChromaticOrb_%d" % i
		# Offset each orb sideways so multiple orbs appear side-by-side, not on top of each other.
		var side: float = float(i) - float(orb_count - 1) * 0.5
		orb.global_position = global_position + orb_dir.orthogonal() * (side * 26.0)
		if orb.has_method("setup"):
			orb.setup(self, get_player(), orb_dir, BASE_BOLT_DAMAGE, BASE_BOLT_COUNT)
		orb.speed = ORB_INITIAL_SPEED * (1.0 + projectile_speed_bonus)
		orb.deceleration = ORB_DECEL
		orb.lifetime = get_effective_duration(ORB_LIFETIME)
		orb.bolt_interval = BOLT_INTERVAL
		orb.bolt_range = 150.0 * get_area_multiplier()
		get_tree().current_scene.add_child(orb)
		var net: Node = get_node_or_null("/root/Net")
		if net and net.has_method("sync_player_projectile"):
			net.sync_player_projectile(orb, ChromaticOrbScene)


## Nearest enemy direction for the throw (else a random direction).
func _aim_direction() -> Vector2:
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
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
