class_name DemolitionistSubclass
extends SubclassBase

## Engineer ascension: explosions leave a burning patch of ground that burns
## enemies inside it. Implemented in grenade_projectile._explode() by spawning a
## FireZone at the blast site when the firing player is_subclass("demolitionist").

func _init() -> void:
	class_id = "demolitionist"
	parent_class_id = "engineer"
	display_name = "Demolitionist"
	description = "Your grenades and explosions leave burning ground that burns enemies inside it."
	starting_stats = {
		"area_bonus": 0.15,
	}
