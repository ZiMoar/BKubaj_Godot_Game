class_name SkeletonArcher
extends EnemyBase

@export var projectile_scene: PackedScene = preload("res://src/entities/enemies/trooper/skeleton_archer/archer_arrow.tscn")
@export var attack_range: float = 300.0
@export var attack_cooldown: float = 2.2
@export var projectile_speed: float = 120.0
@export var projectile_damage: int = 4

var _attack_timer: float = 0.0


func _ready() -> void:
	doodle_kind = 2  # diamond (ranged)
	doodle_color = Color(0.3, 0.8, 0.5)
	doodle_size = 7.0
	speed = 55.0  # Slower than regular skeletons (80)
	max_health = 45
	contact_damage = 6
	xp_value = 4
	xp_orb_tier = 2
	weight = 4.0
	max_knockback_speed = 200.0
	knockback_decay = 14.0
	stat_scale_per_difficulty = 0.3
	damage_scale_ratio = 0.35

	super._ready()


func _physics_process(delta: float) -> void:
	_process_status_dots(delta)
	if target_player == null:
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player == null:
			return

	var to_player: Vector2 = target_player.global_position - global_position
	var dist: float = to_player.length()

	# Approach until near attack range, then hold position and shoot.
	var move_dir: Vector2 = Vector2.ZERO
	if dist > attack_range * 0.85:
		move_dir = to_player.normalized()

	velocity = (move_dir * speed) + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	_process_body_contacts()

	_attack_timer -= delta
	if _attack_timer <= 0.0 and dist <= attack_range:
		_fire_arrow()
		_attack_timer = attack_cooldown


func _fire_arrow() -> void:
	if projectile_scene == null or target_player == null or not is_instance_valid(target_player):
		return

	var arrow: Area2D = projectile_scene.instantiate() as Area2D
	get_tree().current_scene.add_child(arrow)
	var dir: Vector2 = (target_player.global_position - global_position).normalized()
	if arrow.has_method("setup"):
		arrow.setup(global_position, dir, projectile_speed, projectile_damage)