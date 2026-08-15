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

enum State { HOMING, ATTACHED }
var state: State = State.HOMING


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


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
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
	var target := _attached
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(damage, is_critical, DamageType.Type.NECROTIC)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if source_weapon and target.is_in_group("enemies"):
			if target.has_method("has_died") and target.has_died():
				source_weapon.apply_explosion_on_kill(global_position, damage)


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
