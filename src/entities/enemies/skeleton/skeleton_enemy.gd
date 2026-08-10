class_name SkeletonEnemy
extends EnemyBase

func _ready() -> void:
	speed = 80.0
	max_health = 50
	contact_damage = 10
	xp_value = 2
	weight = 4.0
	max_knockback_speed = 210.0
	knockback_decay = 14.0
	stat_scale_per_difficulty = 0.225  # VERY slight stat scaling (compensated for per-minute difficulty)
	
	super._ready()
