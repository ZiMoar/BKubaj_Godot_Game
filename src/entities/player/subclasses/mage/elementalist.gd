class_name ElementalistSubclass
extends SubclassBase

## Mage ascension: attacks exploit enemies afflicted by a different element than
## your own. Implemented in enemy_base.gd (has_ailment_of_different_type +
## ELEMENTALIST_BONUS_MULT in take_damage), gated on
## Player.is_subclass("elementalist").

func _init() -> void:
	class_id = "elementalist"
	parent_class_id = "mage"
	display_name = "Elementalist"
	description = "Your attacks exploit enemies afflicted by a different element than your own."
	starting_stats = {
		"ailment_chance": 0.05,
	}
