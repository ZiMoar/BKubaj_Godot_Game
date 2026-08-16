class_name BatEnemy
extends EnemyBase

## Dasher-category enemy: a tiny flying bat. It flutters toward the player and,
## when it gets close, dashes sharply at them — overshooting so it ends up
## slightly BEHIND the player before circling back. Built for swarms: weak and
## small, but a coordinated pack is dangerous.
##
## Flying enemy: it lives on its own physics layer (Flying Enemies) so bats
## collide with each other but NOT with walking enemies.

@export var dash_range: float = 130.0
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.35
@export var dash_cooldown: float = 1.6

var _dash_timer: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	doodle_kind = 3  # triangle (dasher)
	doodle_color = Color(0.6, 0.3, 0.85)
	doodle_size = 6.0
	add_to_group("flying_enemies")
	speed = 90.0
	max_health = 30               # Tiny and fragile
	contact_damage = 4
	damage_cooldown = 1.0
	xp_value = 2
	weight = 2.0
	max_knockback_speed = 260.0
	knockback_decay = 16.0
	stat_scale_per_difficulty = 0.2
	damage_scale_ratio = 0.35

	super._ready()


func _physics_process(delta: float) -> void:
	_process_status_dots(delta)
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player == null:
			return

	var to_player: Vector2 = target_player.global_position - global_position
	var dist: float = to_player.length()

	# Drive the current dash.
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_velocity + knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
		_process_body_contacts()
		return

	if _dash_cooldown_remaining > 0.0:
		_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)

	# Normal chase toward the player.
	var direction: Vector2 = to_player.normalized()
	velocity = (direction * get_effective_speed(delta)) + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	_process_body_contacts()

	# Trigger a dash when close and off cooldown.
	if dist <= dash_range and _dash_cooldown_remaining <= 0.0:
		# Dash toward the player, overshooting slightly behind them.
		_dash_velocity = direction * dash_speed
		_dash_timer = dash_duration
		_dash_cooldown_remaining = dash_cooldown