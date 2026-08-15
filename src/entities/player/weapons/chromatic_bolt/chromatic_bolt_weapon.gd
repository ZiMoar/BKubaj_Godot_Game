extends Weapon

## Chromatic Bolt — automatic. Throws an orb that decelerates and comes to rest,
## then lingers; while it's alive it fires bolts of RANDOM damage type at nearby
## enemies. The orb itself deals no damage and passes through enemies. Projectile
## count raises the number of BOLTS per volley (not the number of orbs).

const ChromaticOrbScene: PackedScene = preload("res://src/entities/projectiles/chromatic_orb/chromatic_orb.tscn")

const ORB_INITIAL_SPEED: float = 240.0
const ORB_DECEL: float = 120.0
const ORB_LIFETIME: float = 4.0
const BOLT_INTERVAL: float = 0.6
const BASE_BOLT_COUNT: int = 3
const BASE_BOLT_DAMAGE: int = 16
const COOLDOWN: float = 2.5


func _ready() -> void:
	weapon_name = "Chromatic Bolt"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.ARCANE  # the orb is arcane; bolts randomize
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

func supports_duration() -> bool:
	return true


func fire() -> void:
	# Aim the throw at the nearest enemy, else a random direction.
	var dir_start: Vector2 = Vector2.RIGHT
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
		dir_start = (nearest.global_position - global_position).normalized()
	else:
		dir_start = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	var orb: Node = ChromaticOrbScene.instantiate()
	orb.name = "ChromaticOrb"
	orb.global_position = global_position
	if orb.has_method("setup"):
		orb.setup(self, get_player(), dir_start, BASE_BOLT_DAMAGE, get_effective_projectile_count(BASE_BOLT_COUNT))
	orb.speed = ORB_INITIAL_SPEED * (1.0 + projectile_speed_bonus)
	orb.deceleration = ORB_DECEL
	orb.lifetime = get_effective_duration(ORB_LIFETIME)
	orb.bolt_interval = BOLT_INTERVAL
	orb.bolt_range = 300.0 * get_area_multiplier()
	get_tree().current_scene.add_child(orb)
