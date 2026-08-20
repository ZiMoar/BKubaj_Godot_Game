class_name RetaliatorSubclass
extends SubclassBase

## Knight ascension: thorns scale with might and sword attacks apply thorns.
## Implemented in player.gd (get_thorns_damage scales by might) and
## sword_weapon.gd (blade strikes carry thorn damage), gated on
## Player.is_subclass("retaliator").

func _init() -> void:
	class_id = "retaliator"
	parent_class_id = "knight"
	display_name = "Retaliator"
	description = "Thorns scale with your might, and your blade strikes carry thorn damage."
	starting_stats = {
		"thorns_flat": 8.0,
	}
