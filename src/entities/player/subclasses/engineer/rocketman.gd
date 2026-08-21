class_name RocketmanSubclass
extends SubclassBase

## Engineer ascension: Rocket Jump's blast radius and knockback are doubled, and
## launching one grants +30% damage and +15% speed for 3s. Implemented in
## player.gd (_rocket_jump_blast + _rocketman_buff_timer).

func _init() -> void:
	class_id = "rocketman"
	parent_class_id = "engineer"
	display_name = "Rocketman"
	description = "Rocket Jump has doubled blast radius and knockback. Launching one grants +30% damage and +15% speed for 3s."
	starting_stats = {
		"move_speed_percent_bonus": 0.08,
	}
