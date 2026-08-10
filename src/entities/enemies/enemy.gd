class_name Enemy
extends EnemyBase

func _ready() -> void:
	speed = 80.0
	max_health = 50
	contact_damage = 10
	xp_value = 1
	weight = 8.0
	max_knockback_speed = 240.0
	knockback_decay = 16.0

	super._ready()
