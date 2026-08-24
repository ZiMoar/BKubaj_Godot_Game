extends Weapon

## Storm Conduit — automatic. A storm overhead strikes RANDOM enemies within
## range, each bolt descending from above like lightning from a storm.
## Projectile Count raises how many random targets are struck per volley.
## Chain adds extra hops from each struck target (no chains by default), so
## it mirrors Chromatic Orb: chains only appear once the anvil grants them.

const LightningStrikeScene: PackedScene = preload("res://src/entities/projectiles/lightning_strike/lightning_strike.tscn")
const StaticChargeScene: PackedScene = preload("res://src/entities/player/weapons/storm_conduit/static_charge.tscn")
const StormCloudScene: PackedScene = preload("res://src/entities/player/weapons/storm_conduit/storm_cloud.tscn")

const BASE_TARGETS: int = 3
const BASE_DAMAGE: int = 28
const STRIKE_RANGE: float = 320.0
const CHAIN_RANGE: float = 210.0
const STRIKE_HEIGHT: float = 260.0   # how far above the target the bolt originates
const COOLDOWN: float = 3.0

# Signature-driven behaviour.
var static_charge: bool = false
var storms_fury: bool = false
var overcast: bool = false
var _fury_count: int = 0
var _storm_cloud: Node = null

# Static Charge tuning.
const CHARGE_RADIUS: float = 55.0
const CHARGE_DAMAGE: int = 10
const CHARGE_DURATION: float = 4.0

# Storm's Fury tuning.
const FURY_RADIUS: float = 150.0
const FURY_EVERY: int = 5

# Overcast tuning.
const OVERCAST_INTERVAL: float = 0.5


func _ready() -> void:
	weapon_name = "Storm Conduit"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.LIGHTNING
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_chain() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return false

func supports_range_damage() -> bool:
	return true


## Storm Conduit's signature upgrades (rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "static_charge",
			"title": "Static Charge",
			"description": "Each strike leaves a charged patch that zaps enemies stepping on it.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.static_charge = true,
		},
		{
			"id": "storms_fury",
			"title": "Storm's Fury",
			"description": "Every 5th strike is a massive bolt that hits all enemies in a wide radius.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.storms_fury = true,
		},
		{
			"id": "overcast",
			"title": "Overcast",
			"description": "A storm cloud follows you, raining lightning on enemies continuously instead of burst volleys.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.overcast = true,
		},
	]


func fire() -> void:
	# Overcast replaces burst volleys with a persistent following cloud.
	if overcast:
		_ensure_storm_cloud()
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		enemies.append(d)
	if enemies.is_empty():
		return
	var origin: Vector2 = global_position
	var strike_range: float = STRIKE_RANGE * get_area_multiplier()

	var in_range: Array[Node2D] = []
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_squared_to(en.global_position) <= strike_range * strike_range:
			in_range.append(en)
	if in_range.is_empty():
		return

	var dmg: int = get_attack_damage(BASE_DAMAGE)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var target_count: int = get_effective_projectile_count(BASE_TARGETS)
	var chain_extra: int = get_effective_chain_count(0)
	var chain_rng: float = CHAIN_RANGE * get_area_multiplier()
	var hit_ids: Dictionary = {}
	var strikes: Array[PackedVector2Array] = []
	var strike_centers: Array[Vector2] = []

	_fury_count += 1
	var fury_bolt: bool = storms_fury and _fury_count % FURY_EVERY == 0

	for i in range(target_count):
		var cluster: Array[Node2D] = []
		var pick: Array[Node2D] = []
		for en in in_range:
			if not hit_ids.has(en.get_instance_id()):
				pick.append(en)
		if pick.is_empty():
			break
		var first: Node2D = pick[randi() % pick.size()]
		hit_ids[first.get_instance_id()] = true
		cluster.append(first)

		var last: Node2D = first
		for c in range(chain_extra):
			var nxt := _find_chain_target(last, in_range, hit_ids, chain_rng)
			if nxt == null:
				break
			hit_ids[nxt.get_instance_id()] = true
			cluster.append(nxt)
			last = nxt

		for e in cluster:
			if not is_instance_valid(e):
				continue
			var dealt: int = dmg
			if close_range_damage_bonus > 0.0 or far_range_damage_bonus > 0.0:
				dealt = maxi(1, int(round(float(dealt) * get_range_damage_multiplier(e.global_position.distance_to(origin)))))
			if e.is_in_group("destructibles"):
				e.take_damage(dealt, false)
			else:
				e.take_damage(dealt, false, damage_type, false, get_ailment_effect_multiplier())
			apply_lifesteal()
			if e.is_in_group("enemies") and e.has_method("has_died") and e.has_died():
				apply_explosion_on_kill(e.global_position, dealt)
			if static_charge:
				_spawn_static_charge(e.global_position)
			strikes.append(_make_strike_poly(origin, e.global_position))
			strike_centers.append(e.global_position)

	# Storm's Fury: on the 5th volley the whole storm surges — every enemy inside
	# the fury radius of each struck target is hit.
	if fury_bolt and not strike_centers.is_empty():
		for center in strike_centers:
			_hit_fury_blast(center, in_range, dmg, crit, origin)

	for pts in strikes:
		_spawn_strike(origin, pts, crit)


## Storm's Fury: one wide-radius burst around the given centre.
func _hit_fury_blast(center: Vector2, pool: Array[Node2D], dmg: int, _crit: bool, origin: Vector2) -> void:
	var radius: float = FURY_RADIUS * get_area_multiplier()
	var hit: Dictionary = {}
	for en in pool:
		if not is_instance_valid(en) or hit.has(en.get_instance_id()):
			continue
		if center.distance_to(en.global_position) <= radius:
			hit[en.get_instance_id()] = true
			var dealt: int = dmg
			if close_range_damage_bonus > 0.0 or far_range_damage_bonus > 0.0:
				dealt = maxi(1, int(round(float(dealt) * get_range_damage_multiplier(en.global_position.distance_to(origin)))))
			if en.is_in_group("destructibles"):
				en.take_damage(dealt, false)
			else:
				en.take_damage(dealt, false, damage_type, false, get_ailment_effect_multiplier())
			apply_lifesteal()
			if en.is_in_group("enemies") and en.has_method("has_died") and en.has_died():
				apply_explosion_on_kill(en.global_position, dealt)
	_spawn_fury_visual(center, radius)


func _spawn_fury_visual(center: Vector2, radius: float) -> void:
	var fx: Node2D = preload("res://src/effects/explosion_effect/explosion_effect.gd").new()
	fx.name = "StormFury"
	fx.global_position = center
	fx.set("max_radius", radius)
	fx.set("color", Color(1.0, 0.85, 1.0))
	get_tree().current_scene.add_child(fx)


## Ensures the Overcast cloud exists, keeping a single persistent storm above
## the player. Refreshes its tuning on each fire.
func _ensure_storm_cloud() -> void:
	if is_instance_valid(_storm_cloud):
		return
	var cloud: Node = StormCloudScene.instantiate()
	cloud.name = "StormCloud"
	var p: Node = get_player()
	cloud.global_position = (p.global_position + Vector2(0, -110)) if p is Node2D else global_position
	if cloud.has_method("setup"):
		cloud.setup(self, BASE_DAMAGE, OVERCAST_INTERVAL, STRIKE_RANGE, CHAIN_RANGE)
	get_tree().current_scene.add_child(cloud)
	_storm_cloud = cloud


## Leaves a charged patch at the given position (Static Charge signature).
func _spawn_static_charge(pos: Vector2) -> void:
	var patch: Node = StaticChargeScene.instantiate()
	patch.name = "StaticCharge"
	patch.global_position = pos
	if patch.has_method("setup"):
		patch.setup(
			CHARGE_RADIUS * get_area_multiplier(),
			0.6,
			get_attack_damage(CHARGE_DAMAGE),
			CHARGE_DURATION,
			self,
		)
	get_tree().current_scene.add_child(patch)
	sync_effect(patch, StaticChargeScene, {
		"radius": CHARGE_RADIUS * get_area_multiplier(),
		"dur": CHARGE_DURATION,
	})


## Builds a jagged poly from a point high above the target down to the target,
## so each bolt reads as striking DOWNWARD from the storm.
func _make_strike_poly(origin: Vector2, target: Vector2) -> PackedVector2Array:
	var top: Vector2 = target + Vector2(0, -STRIKE_HEIGHT)
	var mid: Vector2 = (top + target) * 0.5 + Vector2(randf_range(-24.0, 24.0), randf_range(-14.0, 6.0))
	return PackedVector2Array([top - origin, mid, target - origin])


func _find_chain_target(from: Node2D, pool: Array[Node2D], hit_ids: Dictionary, chain_rng: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = chain_rng * chain_rng
	for en in pool:
		if not is_instance_valid(en) or hit_ids.has(en.get_instance_id()):
			continue
		var d: float = from.global_position.distance_squared_to(en.global_position)
		if d <= best_d:
			best_d = d
			best = en
	return best


## Shared by fire() and the Overcast cloud: spawns a single downward bolt visual.
func _spawn_bolt_visual(origin: Vector2, target: Vector2, crit: bool) -> void:
	_spawn_strike(origin, _make_strike_poly(origin, target), crit)


func _spawn_strike(origin: Vector2, pts: PackedVector2Array, crit: bool) -> void:
	var bolt: Node = LightningStrikeScene.instantiate()
	if bolt == null or not bolt.has_method("setup"):
		return
	bolt.global_position = origin
	var col := Color(0.6, 0.85, 1.0) if not crit else Color(1.0, 0.5, 0.95)
	bolt.setup(pts, col)
	get_tree().current_scene.add_child(bolt)
	sync_effect(bolt, LightningStrikeScene, {"poly": pts, "color": col})
