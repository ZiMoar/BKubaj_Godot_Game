class_name SlayerSubclass
extends SubclassBase

## Berserker ascension: Spin Axe's outer-edge double-damage sweet spot widens to
## double its size and its cooldown is reduced. Implemented in spin_axe_weapon.

func _init() -> void:
	class_id = "slayer"
	parent_class_id = "berserker"
	display_name = "Slayer"
	description = "Spin Axe's outer-edge sweet spot is twice as wide and its cooldown is reduced."
	starting_stats = {
		"area_bonus": 0.10,
	}
