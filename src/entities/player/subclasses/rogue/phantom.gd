class_name PhantomSubclass
extends SubclassBase

## Rogue ascension: while invisible you move faster, your next attack after
## reappearing deals +100% damage, and nearby enemies are slowed when you vanish.
## Implemented in player.gd (_start_invisibility + get_attack_damage + speed).

func _init() -> void:
	class_id = "phantom"
	parent_class_id = "rogue"
	display_name = "Phantom"
	description = "While invisible you move faster. Vanish slows nearby enemies and your next attack after reappearing deals double damage."
	starting_stats = {
		"move_speed_percent_bonus": 0.05,
	}
