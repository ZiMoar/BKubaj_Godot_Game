extends Weapon

## Bursting Plague — automatic. Launches plague bolts at enemies. Each bolt
## inflicts a low NECROTIC damage-over-time that ramps up over its duration.
## When an infected enemy dies, the plague spreads to a random enemy in range.
## Chain upgrades raise how many enemies it spreads to at once; Duration sets
## how long each plague lasts (its lifetime).

const PlagueBoltScene: PackedScene = preload("res://src/entities/projectiles/plague_bolt/plague_bolt.tscn")

const BASE_DAMAGE: int = 10           # small direct hit on impact
const BASE_SPEED: float = 240.0
const PLAGUE_BASE_TICK: int = 8       # starting tick damage
const PLAGUE_INTERVAL: float = 0.8    # seconds per tick
const PLAGUE_RAMP: float = 1.4        # per-tick damage multiplier
const PLAGUE_DURATION: float = 6.0    # lifetime (Duration scales this)
const SPREAD_RANGE: float = 160.0
const COOLDOWN: float = 4.0

# Signature-driven behaviour.
var contagion: bool = false
var black_death: bool = false
var pestilence: bool = false

# Pestilence (decaying) tuning: ticks start strong and fade out over the lifetime.
const PESTILENCE_START: float = 2.6
const PESTILENCE_DECAY: float = 0.85
const PESTILENCE_FLOOR: float = 0.35

# Black Death tuning: how often a host leaks plague to a neighbour.
const BLACK_DEATH_EMIT: float = 2.5


func _ready() -> void:
	weapon_name = "Bursting Plague"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.NECROTIC
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_chain() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

func supports_duration() -> bool:
	return true


## Bursting Plague's signature upgrades (rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "contagion",
			"title": "Contagion",
			"description": "Spread can re-infect enemies already carrying plague, stacking more damage onto them.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.contagion = true,
		},
		{
			"id": "black_death",
			"title": "Black Death",
			"description": "Plague-ridden enemies periodically leak plague to a nearby enemy without dying.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.black_death = true,
		},
		{
			"id": "pestilence",
			"title": "Pestilence",
			"description": "The plague's damage starts strong and fades over time instead of ramping up.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.pestilence = true,
		},
	]


## Whether an enemy already carries a plague (tracks via the host's meta).
func _has_plague(enemy: Node2D) -> bool:
	return enemy != null and int(enemy.get_meta("plague_hosts", 0)) > 0


func fire() -> void:
	var aim: Vector2 = _aim_direction()
	var count: int = get_effective_projectile_count(1)
	var spread_deg: float = 12.0
	for i in range(count):
		var t: float = 0.0
		if count > 1:
			t = float(i) / float(count - 1)
		var ang: float = deg_to_rad(-spread_deg / 2.0) + deg_to_rad(spread_deg) * t
		var dir: Vector2 = aim.rotated(ang)

		var bolt: Node = PlagueBoltScene.instantiate()
		bolt.name = "PlagueBolt_%d" % i
		var side: float = float(i) - float(count - 1) * 0.5
		var start: Vector2 = global_position + dir.orthogonal() * (side * 20.0)
		bolt.global_position = start
		if bolt.has_method("setup"):
			var dmg: int = get_attack_damage(BASE_DAMAGE)
			var crit: bool = roll_critical_hit()
			if crit:
				dmg = int(round(float(dmg) * get_critical_multiplier()))
			bolt.setup(
				start, dir,
				get_effective_projectile_speed(BASE_SPEED),
				dmg, crit, get_player(), self,
				get_attack_damage(PLAGUE_BASE_TICK),
				PLAGUE_INTERVAL, PLAGUE_RAMP,
				get_effective_duration(PLAGUE_DURATION),
				get_effective_chain_count(1),
				SPREAD_RANGE * get_area_multiplier(),
			)
		get_tree().current_scene.add_child(bolt)
		sync_projectile(bolt, PlagueBoltScene)


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
