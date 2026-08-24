extends Weapon

## Smite — automatic. Strikes the nearest enemy with holy energy. If the strike
## KILLS the target, the overkill (damage above the enemy's remaining health)
## is released as a wave of holy damage around the target, damaging nearby foes.

const SMITE_RANGE: float = 300.0
const BASE_DAMAGE: int = 55
const WAVE_RADIUS: float = 150.0
const WAVE_DAMAGE_RATIO: float = 1.0   # the wave deals the full overkill amount
const COOLDOWN: float = 2.5

# Signature-driven behaviour.
var divine_retribution: bool = false
var holy_chain: bool = false
var condemn: bool = false
var _condemned: Array[Node2D] = []

# Divine Retribution tuning: non-killing hits at/above this fraction of max HP
# release a small holy pulse.
const RETRIBUTION_PCT: float = 0.5
const RETRIBUTION_PULSE: float = 0.5   # small wave = 50% of the overkill wave

# Holy Chain tuning.
const CHAIN_DEPTH_CAP: int = 6


func _ready() -> void:
	weapon_name = "Smite"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.HOLY
	super._ready()
	call_deferred("try_fire")


func supports_range_damage() -> bool:
	return true

func supports_area() -> bool:
	return true


## Smite's signature upgrades (rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "divine_retribution",
			"title": "Divine Retribution",
			"description": "Even non-killing strikes that deal at least half an enemy's max health release a small holy pulse.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.divine_retribution = true,
		},
		{
			"id": "holy_chain",
			"title": "Holy Chain",
			"description": "A holy wave that kills an enemy triggers another Smite on the nearest foe.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.holy_chain = true,
		},
		{
			"id": "condemn",
			"title": "Condemn",
			"description": "Enemies caught in the holy wave are marked; your next Smite strikes every marked enemy.",
			"value": 1,
			"apply": func(w: Weapon) -> void: w.condemn = true,
		},
	]


func fire() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var origin: Vector2 = global_position
	var smite_range: float = SMITE_RANGE * get_area_multiplier()

	var targets: Array[Node2D] = []
	var seen: Dictionary = {}

	# Condemn: strike every marked enemy first.
	if condemn:
		var kept: Array[Node2D] = []
		for m: Node2D in _condemned:
			if not is_instance_valid(m):
				continue
			if origin.distance_to(m.global_position) <= smite_range:
				targets.append(m)
				seen[m.get_instance_id()] = true
				kept.append(m)
		_condemned = kept

	# Always also strike the nearest enemy if one is in range and not already hit.
	var nearest: Node2D = null
	var best_d: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if seen.has(en.get_instance_id()):
			continue
		var d: float = origin.distance_squared_to(en.global_position)
		if d <= smite_range * smite_range and d < best_d:
			best_d = d
			nearest = en
	if nearest != null:
		targets.append(nearest)

	# Clear marks once consumed.
	_condemned = []

	for t: Node2D in targets:
		_smite_strike_at(t, origin, 0)


## One full smite strike on a target (used by fire and Holy Chain). Deals damage,
## then releases the overkill as a holy wave on kill (or a small pulse under
## Divine Retribution on a heavy non-kill). Cascades under Holy Chain.
func _smite_strike_at(target: Node2D, origin: Vector2, depth: int) -> void:
	if not is_instance_valid(target):
		return

	var dealt: int = get_attack_damage(BASE_DAMAGE)
	var crit: bool = roll_critical_hit()
	if crit:
		dealt = int(round(float(dealt) * get_critical_multiplier()))
	if close_range_damage_bonus > 0.0 or far_range_damage_bonus > 0.0:
		dealt = maxi(1, int(round(float(dealt) * get_range_damage_multiplier(target.global_position.distance_to(origin)))))

	var health_before: int = int(target.get("current_health"))
	var overkill: int = maxi(0, dealt - health_before)
	var max_health: int = int(target.get("max_health")) if "max_health" in target else health_before

	_spawn_strike_visual(target.global_position)

	target.take_damage(dealt, crit, damage_type, false, get_ailment_effect_multiplier())
	apply_lifesteal()

	var killed: bool = (target.has_method("has_died") and target.has_died()) or int(target.get("current_health")) <= 0
	if killed:
		apply_explosion_on_kill(target.global_position, dealt)

	if killed or overkill > 0:
		_release_holy_wave(target.global_position, maxi(1, overkill), depth)
	elif divine_retribution and max_health > 0 and float(dealt) >= RETRIBUTION_PCT * float(max_health):
		var pulse: int = maxi(1, int(round(float(dealt) * RETRIBUTION_PULSE)))
		_release_holy_wave(target.global_position, pulse, depth)


func _release_holy_wave(origin: Vector2, wave_damage: int, depth: int) -> void:
	var radius: float = WAVE_RADIUS * get_area_multiplier()
	_spawn_wave_visual(origin, radius)
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null or origin.distance_to(en.global_position) > radius:
			continue
		if en.has_method("take_damage"):
			en.take_damage(wave_damage, false, damage_type, false, get_ailment_effect_multiplier())
			if en.has_method("has_died") and en.has_died():
				apply_explosion_on_kill(en.global_position, wave_damage)
			if condemn:
				_condemned.append(en)
			# Holy Chain: a wave that kills an enemy triggers another Smite.
			if holy_chain and depth < CHAIN_DEPTH_CAP and (en.has_method("has_died") and en.has_died()):
				var follow: Node2D = _nearest_enemy_to(origin, en)
				if follow != null:
					_smite_strike_at(follow, origin, depth + 1)


func _nearest_enemy_to(origin: Vector2, exclude: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == exclude or en == null:
			continue
		var d: float = origin.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _spawn_strike_visual(pos: Vector2) -> void:
	var fx: Node2D = preload("res://src/effects/explosion_effect/explosion_effect.gd").new()
	fx.name = "SmiteStrike"
	fx.global_position = pos
	fx.set("max_radius", 36.0)
	fx.set("color", Color(1.0, 0.95, 0.7))
	get_tree().current_scene.add_child(fx)


func _spawn_wave_visual(origin: Vector2, radius: float) -> void:
	var fx: Node2D = preload("res://src/effects/explosion_effect/explosion_effect.gd").new()
	fx.name = "SmiteWave"
	fx.global_position = origin
	fx.set("max_radius", radius)
	fx.set("color", Color(1.0, 0.9, 0.6))
	get_tree().current_scene.add_child(fx)
