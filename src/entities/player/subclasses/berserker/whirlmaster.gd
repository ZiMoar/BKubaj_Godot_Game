class_name WhirlmasterSubclass
extends SubclassBase

## Berserker ascension: Whirlwind's cooldown drops to 1s and is now shortened by
## attack speed. Implemented in player.gd (_effective_dash_cooldown).

func _init() -> void:
	class_id = "whirlmaster"
	parent_class_id = "berserker"
	display_name = "Whirlmaster"
	description = "Whirlwind's cooldown is cut to 1 second, and attack speed makes it even shorter."
	starting_stats = {
		"move_speed_percent_bonus": 0.05,
	}
