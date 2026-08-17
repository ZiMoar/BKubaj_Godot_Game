class_name SkeletonGeneral
extends BossEnemy

## The Skeleton General — a unique boss. Sequences through three telegraphed
## attacks: an AoE slam, a fan arrow volley, and a skeleton summon.

@export var volley_projectile_scene: PackedScene = preload("res://src/entities/enemies/bosses/skeleton_general/boss_arrow.tscn")
@export var summon_enemy_scene: PackedScene = preload("res://src/entities/enemies/swarmer/skeleton/skeleton_enemy.tscn")

@export var slam_radius: float = 240.0
@export var slam_damage: int = 50
@export var volley_count: int = 7
@export var volley_speed: float = 300.0
@export var volley_spread_deg: float = 45.0
@export var volley_damage: int = 28
@export var summon_count: int = 4


func _ready() -> void:
	doodle_kind = 5  # star (boss)
	doodle_color = Color(0.9, 0.8, 0.4)
	doodle_size = 14.0
	boss_display_name = "Skeleton General"
	# Difficulty scaling is re-enabled: the boss grows with each combat room.
	# The base stats below are chosen so the FIRST room (difficulty 5) matches the
	# old fixed values exactly (4200 HP / 55 contact / 72 speed) — EnemyBase
	# multiplies them by (1 + stat_scale_per_difficulty * difficulty), which at
	# difficulty 5 and stat_scale_per_difficulty 0.06 is 1.30x for health/contact
	# and 1.06x for speed (0.2 speed ratio).
	max_health = 3231
	speed = 68.0
	contact_damage = 42
	xp_value = 100
	xp_orb_tier = 5
	weight = 500.0
	max_knockback_speed = 0.0
	knockback_decay = 0.0
	stat_scale_per_difficulty = 0.06
	move_time = 1.4
	collide_with_player = true  # the boss body-blocks the player

	super._ready()

	register_attack(1.2, 0.3, 1.0, { "type": "slam" })
	register_attack(1.0, 0.6, 1.2, { "type": "volley" })
	register_attack(1.2, 0.5, 1.5, { "type": "summon" })


func _begin_telegraph(attack: Dictionary) -> void:
	super._begin_telegraph(attack)
	match attack.get("type"):
		"slam":
			if telegraph and telegraph.has_method("show_circle"):
				telegraph.show_circle(slam_radius, Color(1, 0.25, 0.25, 0.35))
		"volley":
			if target_player and telegraph and telegraph.has_method("show_line"):
				var dir: Vector2 = (target_player.global_position - global_position).normalized()
				telegraph.show_line(650.0, dir, Color(1, 0.6, 0.2, 0.5))
		"summon":
			if telegraph and telegraph.has_method("show_circle"):
				telegraph.show_circle(150.0, Color(0.6, 0.4, 1.0, 0.35))


func _begin_execution(attack: Dictionary) -> void:
	match attack.get("type"):
		"slam":
			_execute_slam()
		"volley":
			_execute_volley()
		"summon":
			_execute_summon()


func _execute_slam() -> void:
	if target_player == null:
		return
	var dist: float = global_position.distance_to(target_player.global_position)
	# Telegraph gave the player time to move out of the radius.
	if dist <= slam_radius + 20.0 and target_player.has_method("take_damage"):
		_deal_player_damage(target_player, slam_damage, self)


func _execute_volley() -> void:
	if target_player == null or volley_projectile_scene == null:
		return
	var base_dir: Vector2 = (target_player.global_position - global_position).normalized()
	for i in range(volley_count):
		var t: float = 0.0
		if volley_count > 1:
			t = float(i) / float(volley_count - 1)
		var angle: float = deg_to_rad(-volley_spread_deg / 2.0) + deg_to_rad(volley_spread_deg) * t
		var dir: Vector2 = base_dir.rotated(angle)
		var proj: Node = volley_projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		if proj.has_method("setup"):
			proj.setup(global_position, dir, volley_speed, volley_damage)


func _execute_summon() -> void:
	if summon_enemy_scene == null:
		return
	for i in range(summon_count):
		var ang: float = randf() * TAU
		var pos: Vector2 = global_position + Vector2(cos(ang), sin(ang)) * 100.0
		var enemy: Node = summon_enemy_scene.instantiate()
		get_tree().current_scene.add_child(enemy)
		if enemy is Node2D:
			(enemy as Node2D).global_position = pos