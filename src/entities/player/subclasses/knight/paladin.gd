class_name PaladinSubclass
extends SubclassBase

## Knight ascension: defensive sustain. Passive (block-heal) implemented in
## knight_shield.gd (BLOCK_HEAL_PER_SEC while the shield is raised, gated on
## Player.is_subclass("paladin")); starting_stats are the static baseline.

func _init() -> void:
	class_id = "paladin"
	parent_class_id = "knight"
	display_name = "Paladin"
	description = "Blocking with your Tower Shield heals you. +HP regen and a sturdier body."
	starting_stats = {
		"hp_regen_per_second": 2.0,
		"max_health_bonus": 20,
	}
