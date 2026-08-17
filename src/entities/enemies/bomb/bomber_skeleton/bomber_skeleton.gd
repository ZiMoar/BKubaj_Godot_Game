class_name BomberSkeleton
extends EnemyBase

## Bomb-category enemy: a kamikaze skeleton that chases the player faster than
## they can run and, when it gets close, arms a short fuse and detonates,
## dealing heavy area damage. It deals NO contact damage — the player must kill
## it before the fuse runs out.

@export var arming_range: float = 14.0
@export var fuse_time: float = 1.0
@export var explosion_damage: int = 45
@export var explosion_radius: float = 100.0

var _fuse_remaining: float = -1.0  # -1 = not armed
var _armed: bool = false

@onready var telegraph: Node2D = get_node_or_null("Telegraph")


func _ready() -> void:
	doodle_kind = 4  # bomb (fuse + spark)
	doodle_color = Color(1.0, 0.35, 0.25)
	doodle_size = 8.0
	add_to_group("bombers")
	speed = 215.0                # Just barely faster than the player's default 200
	max_health = 60              # Squishy — the threat is the boom, not the body
	contact_damage = 0           # No contact damage — it explodes instead
	xp_value = 4
	xp_orb_tier = 2
	weight = 15.0
	max_knockback_speed = 200.0
	knockback_decay = 14.0
	stat_scale_per_difficulty = 0.5
	damage_scale_ratio = 0.35
	speed_scale_per_difficulty = 0.0  # bomber is already faster than the player; don't let it get faster

	super._ready()


func _physics_process(delta: float) -> void:
	_process_status_dots(delta)
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player == null:
			return

	var dist: float = global_position.distance_to(target_player.global_position)

	# Detect being close enough to the player to arm the fuse.
	if not _armed and dist <= arming_range + 10.0:
		_arm()

	if _armed:
		# Stop chasing and count down the fuse to detonation.
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
		_fuse_remaining -= delta
		_pulse_telegraph()
		if _fuse_remaining <= 0.0:
			_detonate()
		return

	var direction: Vector2 = (target_player.global_position - global_position).normalized()
	velocity = (direction * get_effective_speed(delta)) + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	# No contact damage — the bomber only hurts via its detonation, so we skip
	# _process_body_contacts (which would otherwise register a 0-damage source
	# hit on the player and interfere with the explosion's per-source cooldown).


func _arm() -> void:
	_armed = true
	_fuse_remaining = fuse_time
	# Telegraph the detonation zone as a warning circle, reusing the boss AoE
	# indicator (same BossTelegraph script) so the player can see the danger area.
	if telegraph and telegraph.has_method("show_circle"):
		telegraph.show_circle(explosion_radius, Color(1, 0.3, 0.2, 0.35))
	# Red flash as a secondary "it's about to blow" cue on the body itself.
	modulate = Color(1, 0.4, 0.3, 1)


func _pulse_telegraph() -> void:
	# Quick pulsing flash as the fuse nears zero.
	modulate = Color(1, 0.3, 0.2, 1) if int(_fuse_remaining * 10.0) % 2 == 0 else Color(1, 0.6, 0.5, 1)


func _detonate() -> void:
	# Clear the warning circle the moment the boom resolves.
	if telegraph and telegraph.has_method("hide_telegraph"):
		telegraph.hide_telegraph()
	if target_player and is_instance_valid(target_player):
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist <= explosion_radius and target_player.has_method("take_damage"):
			_deal_player_damage(target_player, explosion_damage, self)
	queue_free()


func die() -> void:
	# Clear the warning circle if the player kills the bomber mid-fuse.
	if telegraph and telegraph.has_method("hide_telegraph"):
		telegraph.hide_telegraph()
	# Standard kill: drops XP/gold and frees. The big boom only happens on the
	# fuse detonating (_detonate), not when the player destroys the bomber.
	super.die()