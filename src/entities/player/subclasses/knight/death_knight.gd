class_name DeathKnightSubclass
extends SubclassBase

## Knight ascension: lifesteal that overheals into a shield, more damage while
## shielded. Implemented in player.gd (heal() overheal->shield; get_attack_damage
## DEATH_KNIGHT_SHIELD_MULT) gated on Player.is_subclass("death_knight").

func _init() -> void:
	class_id = "death_knight"
	parent_class_id = "knight"
	display_name = "Death Knight"
	description = "Lifesteal past full health becomes a shield. Deal more damage while shielded."
	starting_stats = {
		"lifesteal_flat": 2.0,
	}
