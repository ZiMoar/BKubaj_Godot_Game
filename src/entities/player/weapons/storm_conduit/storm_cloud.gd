class_name StormCloud
extends Node2D

## Persistent storm cloud summoned above the player by Storm Conduit's
## "Overcast" signature. Instead of firing burst volleys on cooldown, a single
## cloud follows the player and rains lightning on random enemies continuously,
## roughly every `strike_interval` seconds. Projectile Count scales strikes per
## interval; Chain still adds hops.

var weapon: Node = null
var base_damage: int = 28
var strike_interval: float = 0.5
var strike_range: float = 320.0
var chain_range: float = 210.0

var _tick: float = 0.5


func _ready() -> void:
	z_index = 5
	_tick = strike_interval


func setup(w: Node, dmg: int, interval: float, srange: float, crange: float) -> void:
	weapon = w
	base_damage = dmg
	strike_interval = interval
	strike_range = srange
	chain_range = crange
	_tick = interval


func _process(delta: float) -> void:
	var p: Node = weapon.get_player() if weapon and weapon.has_method("get_player") else null
	if is_instance_valid(p):
		global_position = (p as Node2D).global_position + Vector2(0, -110)
	queue_redraw()
	_tick -= delta
	if _tick <= 0.0:
		_tick = strike_interval
		_strike()


func _strike() -> void:
	if weapon == null:
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		enemies.append(d)
	var origin: Vector2 = global_position
	# Cap so the Area stat can't make bolts streak across the whole screen.
	var srange: float = minf(strike_range * weapon.get_area_multiplier(), strike_range)
	var in_range: Array[Node2D] = []
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_squared_to(en.global_position) <= srange * srange:
			in_range.append(en)
	if in_range.is_empty():
		return

	var count: int = weapon.get_effective_projectile_count(1)
	var chain_extra: int = weapon.get_effective_chain_count(0)
	var crange: float = minf(chain_range * weapon.get_area_multiplier(), chain_range)
	var hit_ids: Dictionary = {}
	for i in range(count):
		var pick: Array[Node2D] = []
		for en in in_range:
			if not hit_ids.has(en.get_instance_id()):
				pick.append(en)
		if pick.is_empty():
			break
		var tgt: Node2D = pick[randi() % pick.size()]
		hit_ids[tgt.get_instance_id()] = true
		_hit_one(tgt, origin)
		var last: Node2D = tgt
		for c in range(chain_extra):
			var nxt: Node2D = weapon._find_chain_target(last, in_range, hit_ids, crange)
			if nxt == null:
				break
			hit_ids[nxt.get_instance_id()] = true
			_hit_one(nxt, origin)
			last = nxt


func _hit_one(tgt: Node2D, origin: Vector2) -> void:
	if not is_instance_valid(tgt):
		return
	var dmg: int = weapon.get_attack_damage(base_damage)
	var crit: bool = weapon.roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * weapon.get_critical_multiplier()))
	if weapon.close_range_damage_bonus > 0.0 or weapon.far_range_damage_bonus > 0.0:
		dmg = maxi(1, int(round(float(dmg) * weapon.get_range_damage_multiplier(tgt.global_position.distance_to(origin)))))
	if tgt.is_in_group("destructibles"):
		tgt.take_damage(dmg, false)
	else:
		tgt.take_damage(dmg, false, DamageType.Type.LIGHTNING, false, weapon.get_ailment_effect_multiplier())
	weapon.apply_lifesteal()
	if tgt.is_in_group("enemies") and tgt.has_method("has_died") and tgt.has_died():
		weapon.apply_explosion_on_kill(tgt.global_position, dmg)
	if weapon.static_charge:
		weapon._spawn_static_charge(tgt.global_position)
	weapon._spawn_bolt_visual(origin, tgt.global_position, crit)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 42.0, Color(0.3, 0.32, 0.38, 0.9))
	draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 24, Color(0.5, 0.55, 0.7, 0.6), 2.0)
