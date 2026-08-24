extends Weapon

## Beehive — automatic. Places a beehive that shoots swarms of bees at nearby
## enemies. Each swarm attaches to an enemy and deals POISON damage in an area
## around it until the target dies, then returns to the hive. The hive persists
## for its duration, releasing swarms periodically.

const BeehiveScene: PackedScene = preload("res://src/entities/player/weapons/beehive/beehive_effect.tscn")

const SPAWN_INTERVAL: float = 1.2
const BASE_SWARM_COUNT: int = 2
const BASE_SWARM_DAMAGE: int = 8
const SWARM_SPEED: float = 260.0
const SWARM_AREA: float = 70.0
const HOME_RANGE: float = 320.0
const BASE_DURATION: float = 8.0
const PLACE_DISTANCE: float = 120.0
const COOLDOWN: float = 7.0

# Signature-driven behaviour.
var hive_mind: bool = false
var sticky_honey: bool = false
var sweet_gift: bool = false

# Sweet Gift tuning.
const SWEET_GIFT_CHANCE: float = 0.10


func _ready() -> void:
	weapon_name = "Beehive"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.POISON
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_area() -> bool:
	return true

func supports_duration() -> bool:
	return true


## Beehive's signature upgrades (rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "hive_mind",
			"title": "Hive Mind",
			"description": "When a swarm kills its target it returns, and the hive sends one extra swarm on the next volley.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.hive_mind = true,
		},
		{
			"id": "sticky_honey",
			"title": "Sticky Honey",
			"description": "Bees' stings leave enemies slowed by sticky honey.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.sticky_honey = true,
		},
		{
			"id": "sweet_gift",
			"title": "Sweet Gift",
			"description": "Each returning swarm has a 10% chance to drop a small healing pickup at the hive.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.sweet_gift = true,
		},
	]


func fire() -> void:
	var pos: Vector2 = _placement()
	var hive: Node = BeehiveScene.instantiate()
	hive.name = "Beehive"
	hive.global_position = pos
	if hive.has_method("setup"):
		hive.setup(
			SPAWN_INTERVAL,
			get_effective_projectile_count(BASE_SWARM_COUNT),
			get_attack_damage(BASE_SWARM_DAMAGE),
			SWARM_SPEED,
			SWARM_AREA * get_area_multiplier(),
			HOME_RANGE,
			get_effective_duration(BASE_DURATION),
			get_player(),
			self,
		)
	get_tree().current_scene.add_child(hive)
	sync_effect(hive, BeehiveScene, {
		"dur": get_effective_duration(BASE_DURATION),
		"area": SWARM_AREA * get_area_multiplier(),
	})


## Place the hive at the nearest enemy, else a short distance in a random dir.
func _placement() -> Vector2:
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
		return nearest.global_position
	var dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	return global_position + dir * PLACE_DISTANCE
