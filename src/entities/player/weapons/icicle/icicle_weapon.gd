extends Weapon

## Icicle — automatic. Throws shards of ice at enemies. Each icicle shatters on
## impact, dealing COLD damage to the struck target and a cone of cold damage
## BEHIND it (past the target, away from the player).

const IcicleScene: PackedScene = preload("res://src/entities/projectiles/icicle/icicle.tscn")

const BASE_DAMAGE: int = 22
const BASE_SPEED: float = 420.0
const CONE_RADIUS: float = 120.0
const CONE_HALF_ANGLE: float = 0.6
const COOLDOWN: float = 2.0

# Signature-driven behaviour.
var splintering: bool = false
var hail: bool = false
var refraction: bool = false
var _hail_tracker: Dictionary = {}   # enemy id -> [count, last_time]

const HAIL_WINDOW: float = 1.2
const HAIL_SHARDS: int = 3


func _ready() -> void:
	weapon_name = "Icicle"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.COLD
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

func supports_area() -> bool:
	return true


## Icicle's signature upgrades (rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "splintering",
			"title": "Splintering",
			"description": "The shatter cone also launches small icicle shards that fly on and hit again.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.splintering = true,
		},
		{
			"id": "hail",
			"title": "Hail",
			"description": "Striking the same enemy twice quickly freezes them solid for a moment.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.hail = true,
		},
		{
			"id": "refraction",
			"title": "Refraction",
			"description": "The shatter becomes a full 360° burst at reduced per-hit damage.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.refraction = true,
		},
	]


## Hail: track repeated hits on the same enemy; freeze on the 2nd within the window.
func _record_hail_hit(enemy: Node2D) -> void:
	if enemy == null or not enemy.has_method("apply_freeze"):
		return
	var key: int = enemy.get_instance_id()
	var entry: Array = _hail_tracker.get(key, [0, -INF])
	if Time.get_ticks_msec() / 1000.0 - float(entry[1]) <= HAIL_WINDOW:
		enemy.apply_freeze()
		_hail_tracker[key] = [0, -INF]
	else:
		_hail_tracker[key] = [1, Time.get_ticks_msec() / 1000.0]


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

		var ic: Node = IcicleScene.instantiate()
		ic.name = "Icicle_%d" % i
		var side: float = float(i) - float(count - 1) * 0.5
		ic.global_position = global_position + dir.orthogonal() * (side * 22.0)
		if ic.has_method("setup"):
			var dmg: int = get_attack_damage(BASE_DAMAGE)
			var crit: bool = roll_critical_hit()
			if crit:
				dmg = int(round(float(dmg) * get_critical_multiplier()))
			ic.setup(
				global_position + dir.orthogonal() * (side * 22.0),
				dir,
				get_effective_projectile_speed(BASE_SPEED),
				dmg,
				crit,
				get_player(),
				self,
				CONE_RADIUS,
				CONE_HALF_ANGLE,
			)
		get_tree().current_scene.add_child(ic)
		sync_projectile(ic, IcicleScene)


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
