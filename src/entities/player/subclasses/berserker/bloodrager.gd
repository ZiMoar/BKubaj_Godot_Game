class_name BloodragerSubclass
extends SubclassBase

## Berserker ascension: your maximum health increases attack speed, and you deal
## increased damage while below half health. Implemented in player.gd
## (get_attack_speed_multiplier + get_attack_damage).

func _init() -> void:
	class_id = "bloodrager"
	parent_class_id = "berserker"
	display_name = "Bloodrager"
	description = "Maximum health increases attack speed. Deal +30% damage while below half health."
	starting_stats = {
		"max_health": 150,
	}
