extends Weapon

## Caltrops — automatic. Throws caltrops in RANDOM directions (not aimed at any
## enemy) that scatter across the ground. Enemies walking over them take PHYSICAL
## damage on a tick while they last; patches are duration-based, not consumed on
## a single hit.

const CaltropsScene: PackedScene = preload("res://src/entities/player/weapons/caltrops/caltrops_effect.tscn")

const BASE_RADIUS: float = 60.0
const TICK_INTERVAL: float = 0.5
const BASE_TICK_DAMAGE: int = 14
const BASE_DURATION: float = 6.0
const THROW_MIN: float = 90.0
const THROW_MAX: float = 230.0
const COOLDOWN: float = 5.0

# Signature-driven behaviour.
var rusty_spikes: bool = false
var wall_of_spikes: bool = false
var barbed_field: bool = false

# Wall of Spikes tuning.
const WALL_LENGTH: float = 300.0
const WALL_WIDTH: float = 34.0

# Barbed Field tuning.
const BARBED_DURATION_MULT: float = 1.5
const BARBED_SLOW_FACTOR: float = 0.65
const BARBED_SLOW_DURATION: float = 1.0


func _ready() -> void:
	weapon_name = "Caltrops"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.PHYSICAL
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_area() -> bool:
	return true

func supports_duration() -> bool:
	return true


## Caltrops' signature upgrades (rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "rusty_spikes",
			"title": "Rusty Spikes",
			"description": "Stepping on a patch applies a stacking physical bleed.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.rusty_spikes = true,
		},
		{
			"id": "wall_of_spikes",
			"title": "Wall of Spikes",
			"description": "Patches form a long thin barrier instead of a compact circle.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.wall_of_spikes = true,
		},
		{
			"id": "barbed_field",
			"title": "Barbed Field",
			"description": "Patches last longer and slow enemies while they stand on them.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.barbed_field = true,
		},
	]


func fire() -> void:
	var count: int = get_effective_projectile_count(2)
	for i in range(count):
		var dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var dist: float = randf_range(THROW_MIN, THROW_MAX)
		var pos: Vector2 = global_position + dir * dist
		var dur: float = get_effective_duration(BASE_DURATION) * (BARBED_DURATION_MULT if barbed_field else 1.0)
		var wall_angle: float = dir.angle() + PI / 2.0   # wall runs perpendicular to the throw
		var patch: Node = CaltropsScene.instantiate()
		patch.name = "Caltrops_%d" % i
		patch.global_position = pos
		if patch.has_method("setup"):
			patch.setup(
				BASE_RADIUS * get_area_multiplier(),
				TICK_INTERVAL,
				get_attack_damage(BASE_TICK_DAMAGE),
				dur,
				self,
				wall_of_spikes,
				wall_angle,
				WALL_LENGTH,
			)
		get_tree().current_scene.add_child(patch)
		sync_effect(patch, CaltropsScene, {
			"radius": BASE_RADIUS * get_area_multiplier(),
			"dur": dur,
			"wall": wall_of_spikes,
			"wall_angle": wall_angle,
			"wall_len": WALL_LENGTH,
		})
