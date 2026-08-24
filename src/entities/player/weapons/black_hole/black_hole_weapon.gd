extends Weapon

## Black Hole — automatic. Opens a black hole at a targeted area that sucks
## enemies toward its centre and deals ARCANE damage to everyone inside every
## half-second, for the hole's duration.

const BlackHoleScene: PackedScene = preload("res://src/entities/player/weapons/black_hole/black_hole_effect.tscn")

const BASE_RADIUS: float = 110.0
const TICK_INTERVAL: float = 0.5
const BASE_TICK_DAMAGE: int = 18
const BASE_DURATION: float = 5.0
const PULL_SPEED: float = 70.0
const PLACE_DISTANCE: float = 200.0
const COOLDOWN: float = 6.0

# Signature-driven behaviour.
var singularity: bool = false
var gravitational_lens: bool = false
var collapse: bool = false

# Collapse tuning.
const COLLAPSE_RADIUS_MULT: float = 1.6
const COLLAPSE_DAMAGE_MULT: float = 5.0


func _ready() -> void:
	weapon_name = "Black Hole"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.ARCANE
	super._ready()
	call_deferred("try_fire")


func supports_area() -> bool:
	return true

func supports_duration() -> bool:
	return true


## Black Hole's signature upgrades (rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "singularity",
			"title": "Singularity",
			"description": "The pull strengthens over time and enemies near the core take bonus damage.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.singularity = true,
		},
		{
			"id": "gravitational_lens",
			"title": "Gravitational Lens",
			"description": "A wider pull that also drags enemy projectiles off course.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.gravitational_lens = true,
		},
		{
			"id": "collapse",
			"title": "Collapse",
			"description": "When the hole expires it violently implodes in a big arcane burst.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.collapse = true,
		},
	]


func fire() -> void:
	var pos: Vector2 = _placement()
	var hole: Node = BlackHoleScene.instantiate()
	hole.name = "BlackHole"
	hole.global_position = pos
	if hole.has_method("setup"):
		var dmg: int = get_attack_damage(BASE_TICK_DAMAGE)
		hole.setup(
			BASE_RADIUS * get_area_multiplier(),
			TICK_INTERVAL,
			dmg,
			get_effective_duration(BASE_DURATION),
			PULL_SPEED,
			self,
		)
	get_tree().current_scene.add_child(hole)
	sync_effect(hole, BlackHoleScene, {
		"radius": BASE_RADIUS * get_area_multiplier(),
		"dur": get_effective_duration(BASE_DURATION),
	})


## Place the hole at the nearest enemy, else a fixed distance in a random dir.
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
