class_name HungrySkull
extends Area2D

## A slowly flying skull (Hungry Skull weapon). Homes toward the nearest enemy;
## once close it attaches to that enemy and deals necrotic damage with rapid
## hits. If the attached enemy dies before the skull's duration ends, it detaches
## and seeks another target.

var damage: int = 8
var is_critical: bool = false
var speed: float = 120.0
var attach_speed: float = 60.0
var attach_range: float = 34.0
var attack_interval: float = 0.28
var lifetime: float = 6.0
var source_player: Node = null
var source_weapon: Node = null

var _attached: Node2D = null
var _age: float = 0.0
var _attack_timer: float = 0.0
## Original lifetime passed in at setup; Sustain extends `lifetime` from here,
## capped at 2x this value.
var _base_lifetime: float = 6.0
const SUSTAIN_MAX_MULT: float = 2.0

enum State { HOMING, ATTACHED }
var state: State = State.HOMING
## Fissure (signature): when this skull's prey dies, it splits into a smaller
## skull that seeks a new target. Tracks how many splits this skull has spawned.
var _fissures_spawned: int = 0
## Only skulls fired directly by the weapon may split. Fissure splits are smaller
## secondary skulls that do NOT split again — without this, every split (a fresh
## skull) could itself split, giving unbounded exponential spread (the same
## runaway the bomb upgrade used to have).
var _can_fissure: bool = true
const FISSURE_MAX: int = 2
const FissureSkullScene: PackedScene = preload("res://src/entities/projectiles/hungry_skull/hungry_skull.tscn")


func _ready() -> void:
	body_entered.connect(_on_hit)


func setup(pos: Vector2, dmg: int, crit: bool, player: Node, weapon: Node, skull_speed: float, dur: float) -> void:
	global_position = pos
	damage = dmg
	is_critical = crit
	source_player = player
	source_weapon = weapon
	speed = skull_speed
	lifetime = dur
	_base_lifetime = dur


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_pop_on_expire()
		return

	match state:
		State.HOMING:
			_home(delta)
		State.ATTACHED:
			_attached_process(delta)


func _home(delta: float) -> void:
	var nearest: Node2D = _nearest_enemy()
	if nearest == null:
		# No target: drift slowly in a straight line.
		global_position += Vector2(cos(_age * 0.8), 0.0) * speed * delta
		return

	var to: Vector2 = nearest.global_position - global_position
	var dist: float = to.length()
	if dist <= attach_range:
		_attach(nearest)
		return
	var step: float = speed * delta
	global_position += (to / maxf(1.0, dist)) * step
	rotation = to.angle()


func _attach(target: Node2D) -> void:
	state = State.ATTACHED
	_attached = target
	_attack_timer = 0.0
	# First tick immediately.
	_attack()


func _attached_process(delta: float) -> void:
	var target := _attached
	# Detach & re-home if the target is gone or dead.
	if target == null or not is_instance_valid(target) or (target.has_method("has_died") and target.has_died()):
		# Sustain: a kill extends the skull's duration (up to double).
		if not get_meta("visual_copy", false) and source_weapon != null and source_weapon.has_method("has_signature") and source_weapon.has_signature("sustain"):
			_extend_lifetime()
		_try_fissure()
		_attached = null
		state = State.HOMING
		return
	# Follow the target.
	global_position = target.global_position
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_attack()


func _attack() -> void:
	# Co-op visual copy: it homes and latches onto an enemy to render the attach,
	# but must never deal necrotic damage (its hits are manual, not physics).
	if get_meta("visual_copy", false):
		return
	var target := _attached
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, is_critical, source_weapon.damage_type if source_weapon != null else DamageType.Type.NECROTIC, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if source_weapon and target.is_in_group("enemies"):
			if target.has_method("has_died") and target.has_died():
				source_weapon.apply_explosion_on_kill(global_position, damage)


## Fissure: when the attached prey dies, this skull splits into a smaller skull
## that seeks a new target (up to FISSURE_MAX times total). Only if the owning
## weapon has the signature.
func _try_fissure() -> void:
	# Co-op visual copy: never split (a split would be a real damaging skull).
	if get_meta("visual_copy", false):
		return
	if not _can_fissure:
		return
	if source_weapon == null or not source_weapon.has_method("has_signature") or not source_weapon.has_signature("fissure"):
		return
	if _fissures_spawned >= FISSURE_MAX:
		return
	_fissures_spawned += 1

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	# Only split spawns once per prey death (the parent re-homes normally).
	if get_tree() == null or get_tree().current_scene == null:
		return
	var split: Node = FissureSkullScene.instantiate()
	split.name = "FissureSkull"
	split._can_fissure = false
	split.global_position = global_position
	var split_dmg: int = maxi(1, int(round(float(damage) * 0.6)))
	if split.has_method("setup"):
		# Shorter duration, slower — a smaller, weaker secondary skull.
		split.setup(global_position, split_dmg, is_critical, source_player, source_weapon, speed * 0.85, maxf(2.0, lifetime * 0.6))
	split.scale = Vector2(0.6, 0.6)
	var t: Node2D = _nearest_enemy()
	if t != null:
		split.look_at(t.global_position)
	get_tree().current_scene.add_child(split)


func _nearest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


## Sustain: extend the skull's lifetime by 1s per kill, capped at 2x original.
func _extend_lifetime() -> void:
	lifetime = minf(_base_lifetime * SUSTAIN_MAX_MULT, lifetime + 1.0)


## Popcorn Skulls: on expiration, deal 5x the skull's hit damage in a 100px blast.
func _pop_on_expire() -> void:
	# Co-op visual copy: never deals real damage — just disappears.
	if not get_meta("visual_copy", false) and source_weapon != null and source_weapon.has_method("has_signature") and source_weapon.has_signature("popcorn_skulls"):
		var boom_dmg: int = maxi(1, int(round(float(damage) * 5.0)))
		var boom_radius: float = 100.0
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var en: Node2D = e as Node2D
			if global_position.distance_to(en.global_position) <= boom_radius:
				en.take_damage(boom_dmg, is_critical, source_weapon.damage_type if source_weapon else DamageType.Type.NECROTIC, false, source_weapon.get_ailment_effect_multiplier() if source_weapon else 1.0)
				if source_player and source_player.has_method("apply_lifesteal"):
					source_player.apply_lifesteal()
				if source_weapon and en.is_in_group("enemies") and en.has_method("has_died") and en.has_died():
					source_weapon.apply_explosion_on_kill(en.global_position, boom_dmg)
		if get_tree() and get_tree().current_scene:
			var ring: Node = RadiusRing.new()
			ring.name = "PopcornRing"
			get_tree().current_scene.add_child(ring)
			ring.global_position = global_position
			if ring.has_method("setup"):
				ring.setup(boom_radius, 0.5, Color(0.6, 0.9, 0.7, 0.7))
	queue_free()


func _on_hit(body: Node2D) -> void:
	if body and body.is_in_group("enemies") and state == State.HOMING:
		_attach(body)


func _draw() -> void:
	var col := Color(0.75, 0.95, 0.8) if state == State.ATTACHED else Color(0.85, 0.85, 0.9)
	draw_circle(Vector2.ZERO, 7.0, Color(0.1, 0.1, 0.12, 0.9))
	# Two glowing eyes.
	draw_circle(Vector2(-2.5, -1.5), 1.8, col)
	draw_circle(Vector2(2.5, -1.5), 1.8, col)
	draw_circle(Vector2(-2.5, -1.5), 0.8, Color.WHITE)
	draw_circle(Vector2(2.5, -1.5), 0.8, Color.WHITE)
