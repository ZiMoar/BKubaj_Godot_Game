class_name SkeletonEnemy
extends EnemyBase

func _ready() -> void:
	doodle_kind = 0  # circle (grunt)
	doodle_color = Color(0.9, 0.9, 0.95)
	doodle_size = 6.0
	speed = 80.0
	max_health = 50
	contact_damage = 7
	xp_value = 2
	weight = 4.0
	max_knockback_speed = 210.0
	knockback_decay = 14.0
	stat_scale_per_difficulty = 0.225  # VERY slight stat scaling (compensated for per-minute difficulty)
	damage_scale_ratio = 0.35  # damage grows far slower than HP late-game
	
	super._ready()
