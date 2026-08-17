class_name BossEnemy
extends EnemyBase

const ARTEFACT_PICKUP_SCENE: PackedScene = preload("res://src/pickups/artefact_pickup/artefact_pickup.tscn")

## Base template for boss enemies. Provides a telegraphed attack-sequence state
## machine (MOVING -> TELEGRAPHING -> EXECUTING -> RECOVERING) and registers a
## boss health bar on the HUD. Subclasses register attacks in _ready() via
## register_attack() and implement the attack hooks below:
##   _begin_telegraph(attack)  - show warning visuals
##   _begin_execution(attack)  - perform the attack's damaging/firing action
##   _update_execution(delta)  - per-frame action while executing (optional)
##   _finish_attack(attack)    - cleanup after the attack resolves

enum BossState { MOVING, TELEGRAPHING, EXECUTING, RECOVERING }

@export var boss_display_name: String = "Boss"
@export var move_time: float = 1.2

var state: BossState = BossState.MOVING
var _state_timer: float = 0.0
var _attack_cycle: Array = []
var _current_attack: Dictionary = {}
var _current_attack_index: int = 0

@onready var telegraph: Node2D = get_node_or_null("Telegraph")


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	state = BossState.MOVING
	_state_timer = move_time
	_register_boss_on_hud()


func _physics_process(delta: float) -> void:
	_process_status_dots(delta)
	# Re-pick the target if the current one is gone or downed, so in co-op the
	# shared boss engages whoever is actually alive and nearest (not the first
	# player it saw at spawn, which could be a downed ghost). Single-player is
	# unaffected: there is only ever one player, so this resolves to the same one.
	if target_player == null or not is_instance_valid(target_player) or _is_player_down(target_player):
		target_player = _pick_nearest_living_player()
		if target_player == null:
			return
	_process_boss_state(delta)
	_process_body_contacts()


func _pick_nearest_living_player() -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for p: Node in get_tree().get_nodes_in_group("player"):
		if _is_player_down(p):
			continue
		var d: float = (p as Node2D).global_position.distance_squared_to(global_position)
		if d < best_dist:
			best_dist = d
			best = p as Node2D
	return best


func _is_player_down(p: Node) -> bool:
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return true
	if p.get("is_ghost") == true:
		return true
	var hp: Variant = p.get("current_health")
	if hp is int and hp <= 0:
		return true
	return false


func _process_boss_state(delta: float) -> void:
	_state_timer -= delta
	match state:
		BossState.MOVING:
			_move_during_idle(delta)
			if _state_timer <= 0.0:
				begin_next_attack()
		BossState.TELEGRAPHING:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			move_and_slide()
			if _state_timer <= 0.0:
				execute_current_attack()
		BossState.EXECUTING:
			_update_execution(delta)
			if _state_timer <= 0.0:
				finish_current_attack()
		BossState.RECOVERING:
			if _state_timer <= 0.0:
				state = BossState.MOVING
				_state_timer = move_time


func _move_during_idle(_delta: float) -> void:
	if target_player == null:
		return
	var to_player: Vector2 = target_player.global_position - global_position
	var dist: float = to_player.length()
	var desired: float = 180.0
	var move_dir: Vector2 = Vector2.ZERO
	if dist > desired + 40.0:
		move_dir = to_player.normalized()
	elif dist < desired - 40.0:
		move_dir = -to_player.normalized()
	# Strafe a little so the boss doesn't sit still while waiting
	move_dir += to_player.normalized().rotated(PI / 2.0) * 0.4
	move_dir = move_dir.normalized()
	velocity = move_dir * speed
	move_and_slide()


# --- Attack sequencing ---

func register_attack(telegraph_time: float, execute_time: float, recovery_time: float, attack_data: Dictionary = {}) -> void:
	var attack: Dictionary = {
		"telegraph": telegraph_time,
		"execute": execute_time,
		"recovery": recovery_time,
	}
	attack.merge(attack_data)
	_attack_cycle.append(attack)


func begin_next_attack() -> void:
	if _attack_cycle.is_empty():
		state = BossState.MOVING
		_state_timer = move_time
		return
	_current_attack = _attack_cycle[_current_attack_index]
	_current_attack_index = (_current_attack_index + 1) % _attack_cycle.size()
	state = BossState.TELEGRAPHING
	_state_timer = float(_current_attack.get("telegraph", 1.0))
	_begin_telegraph(_current_attack)


func execute_current_attack() -> void:
	if _current_attack.is_empty():
		state = BossState.MOVING
		_state_timer = move_time
		return
	state = BossState.EXECUTING
	_state_timer = float(_current_attack.get("execute", 0.4))
	_begin_execution(_current_attack)


func finish_current_attack() -> void:
	_finish_attack(_current_attack)
	state = BossState.RECOVERING
	_state_timer = float(_current_attack.get("recovery", 0.8))


# --- Subclass hooks ---

func _begin_telegraph(_attack: Dictionary) -> void:
	if telegraph and telegraph.has_method("hide_telegraph"):
		telegraph.hide_telegraph()


func _begin_execution(_attack: Dictionary) -> void:
	pass


func _update_execution(_delta: float) -> void:
	pass


func _finish_attack(_attack: Dictionary) -> void:
	if telegraph and telegraph.has_method("hide_telegraph"):
		telegraph.hide_telegraph()


# --- Boss death drop ---

func die() -> void:
	_drop_artefact()
	super.die()


func _drop_artefact() -> void:
	# die() runs during a physics collision callback, so adding an Area2D to the
	# tree right away would flush queries mid-step. Defer the spawn instead.
	var spawn_pos: Vector2 = global_position
	_spawn_relic_pickup.call_deferred(spawn_pos)


func _spawn_relic_pickup(at_pos: Vector2) -> void:
	if ARTEFACT_PICKUP_SCENE == null:
		return
	# Co-op: the boss is host-simulated, so its relic must be spawned on EVERY
	# machine (each player picks up their own copy). Route through EnemyNet.
	var net: Node = get_node_or_null("/root/Net")
	if _enemy_net_id >= 0 and net != null and net.active():
		var enemy_net: Node = get_tree().get_first_node_in_group("enemy_net")
		if enemy_net and enemy_net.has_method("spawn_boss_relic"):
			enemy_net.rpc("spawn_boss_relic", at_pos)
			return
	var pickup: ArtefactPickup = ARTEFACT_PICKUP_SCENE.instantiate() as ArtefactPickup
	if pickup == null:
		return
	pickup.global_position = at_pos
	var scene: Node = get_tree().current_scene
	if scene:
		scene.add_child(pickup)


# --- HUD boss bar ---

func _register_boss_on_hud() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_boss"):
		hud.register_boss(self)
