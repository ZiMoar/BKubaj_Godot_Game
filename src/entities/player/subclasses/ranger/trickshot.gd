class_name TrickshotSubclass
extends SubclassBase

## Ranger ascension: arrows pierce and chain to twice as many enemies.
## Implemented in arrow_proj.setup() by doubling pierce/chain when the firing
## player is_subclass("trickshot") — covers Longbow and Rain of Arrows alike.

func _init() -> void:
	class_id = "trickshot"
	parent_class_id = "ranger"
	display_name = "Trickshot"
	description = "Your arrows pierce and chain to twice as many enemies."
	starting_stats = {
		"pierce_bonus": 1,
	}
