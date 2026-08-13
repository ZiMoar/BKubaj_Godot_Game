class_name SkeletonNecromancer
extends EnemyBase

## Disruptor-category enemy: a skeleton caster that keeps its distance from the
## player and periodically raises new, normal skeletons to fight for it. Medium
## HP — tougher than a skeleton, weaker than a brute. It is a backline threat:
## the player must push through the minions it spawns to reach it.

@export var skel_scene: PackedScene = preload("res://src/entities/enemies/swarmer/skeleton/skeleton_enemy.tscn")
@export var preferred_range: float = 260.0
@export var back_off_range: float = 150.0
@export var summon_cooldown: float = 4.0
@export var summon_count: int = 2
@export var summon_radius: float = 40.0

var _summon_timer: float = 0.0


func _ready() -> void:
	speed = 55.0
	max_health = 90               # Medium HP (between skeleton 50 and brute 140)
	contact_damage = 6
	damage_cooldown = 1.0
	xp_value = 6
	weight = 22.0
	max_knockback_speed = 180.0
	knockback_decay = 12.0
	stat_scale_per_difficulty = 0.6
	damage_scale_ratio = 0.35

	super._ready()
	_summon_timer = summon_cooldown * 0.5


func _physics_process(delta: float) -> void:
	_process_status_dots(delta)
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		if target_player == null:
			return

	var to_player: Vector2 = target_player.global_position - global_position
	var dist: float = to_player.length()

	# Keep distance: back off when too close, advance when too far, hold mid-range.
	var move_dir: Vector2 = Vector2.ZERO
	if dist < back_off_range:
		move_dir = -to_player.normalized()
	elif dist > preferred_range:
		move_dir = to_player.normalized()

	velocity = (move_dir * get_effective_speed(delta)) + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	_process_body_contacts()

	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon()
		_summon_timer = summon_cooldown


func _summon() -> void:
	if skel_scene == null:
		return
	for i in range(summon_count):
		if skel_scene == null:
			return
		var skel: Node = skel_scene.instantiate()
		if skel is Node2D:
			var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * summon_radius
			(skel as Node2D).global_position = global_position + offset
		get_tree().current_scene.add_child(skel)