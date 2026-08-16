class_name SkeletonBrute
extends EnemyBase

func _ready() -> void:
	doodle_kind = 1  # square (tank)
	doodle_color = Color(0.45, 0.15, 0.75)
	doodle_size = 10.0
	max_health = 140
	speed = 42.0
	contact_damage = 12
	damage_cooldown = 1.1
	xp_value = 8
	xp_orb_tier = 3
	weight = 28.0
	max_knockback_speed = 180.0
	knockback_decay = 12.0
	stat_scale_per_difficulty = 0.5  # Lower scaling so brute contact damage (and HP) don't oneshot late-game
	damage_scale_ratio = 0.35
	collide_with_player = true  # brute body-blocks the player

	super._ready()