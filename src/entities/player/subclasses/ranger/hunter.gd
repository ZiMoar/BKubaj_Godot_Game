class_name HunterSubclass
extends SubclassBase

## Ranger ascension: hits mark enemies, who take increased damage from all
## sources. Implemented via enemy_base's hunter mark (see HUNTER_MARK_* and the
## take_damage hook), driven by Player.is_subclass("hunter").

func _init() -> void:
	class_id = "hunter"
	parent_class_id = "ranger"
	display_name = "Hunter"
	description = "Your attacks mark enemies, who take increased damage from all sources."
	starting_stats = {
		"area_bonus": 0.05,
	}
