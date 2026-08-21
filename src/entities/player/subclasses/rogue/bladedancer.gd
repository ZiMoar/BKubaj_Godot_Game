class_name BladedancerSubclass
extends SubclassBase

## Rogue ascension: damage scales with your evasion, and you roll your dodge
## chance twice (dodging if either roll succeeds). Implemented in player.gd
## (get_attack_damage + take_damage dodge roll).

func _init() -> void:
	class_id = "bladedancer"
	parent_class_id = "rogue"
	display_name = "Bladedancer"
	description = "Damage scales with your evasion. You roll your dodge chance twice — dodging if either roll succeeds."
	starting_stats = {
		"evasion_chance": 8.0,
	}
