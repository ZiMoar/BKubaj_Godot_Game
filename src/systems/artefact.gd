class_name Artefact
extends RefCounted

## Static registry for Artefacts — cross-stat interaction relics that drop
## from bosses and equip into the player's 5 artefact slots.
##
## Each artefact changes how two (or more) of the player's base stats combine.
## The effects themselves live in player.gd; this class only stores metadata
## (id/name/description/color) and lookup helpers.

const ARTEFACT_POOL: Array[Dictionary] = [
	{
		"id": "armor_to_thorns",
		"name": "Barbed Shell",
		"desc": "Your Armor is added to your Thorns damage.",
		"color": Color(0.55, 0.82, 0.9),
	},
	{
		"id": "lifesteal_crit",
		"name": "Vampiric Rage",
		"desc": "Your Lifesteal heals can critically strike for double healing.",
		"color": Color(0.95, 0.35, 0.2),
	},
	{
		"id": "lifesteal_to_damage",
		"name": "Blood Pact",
		"desc": "Deal up to +3% damage for each point of Lifesteal.",
		"color": Color(0.9, 0.2, 0.42),
	},
	{
		"id": "maxhp_to_armor",
		"name": "Iron Heart",
		"desc": "Gain Armor equal to 20% of your Max Health.",
		"color": Color(0.62, 0.62, 0.78),
	},
	{
		"id": "regen_to_attack_speed",
		"name": "Metabolic Boost",
		"desc": "Regenerate: each point of HP Regen adds Attack Speed.",
		"color": Color(0.3, 0.8, 0.5),
	},
	{
		"id": "thorns_to_damage",
		"name": "Thorned Wrath",
		"desc": "Deal up to +2% damage for each point of Thorns.",
		"color": Color(0.36, 0.76, 0.3),
	},
	{
		"id": "golden_touch",
		"name": "Golden Touch",
		"desc": "Gain +50% gold from all sources.",
		"color": Color(1.0, 0.85, 0.25),
	},
	{
		"id": "greed_to_xp",
		"name": "Enlightened Greed",
		"desc": "Gold gained also grants 25% of its value as XP.",
		"color": Color(0.85, 0.9, 0.4),
	},
	{
		"id": "armor_to_gold",
		"name": "Midas Bulwark",
		"desc": "Gold pickups are worth extra equal to 20% of your Armor.",
		"color": Color(0.85, 0.7, 0.25),
	},
]


static func get_def(artefact_id: String) -> Dictionary:
	for def: Dictionary in ARTEFACT_POOL:
		if def["id"] == artefact_id:
			return def
	return {}


static func get_display_name(artefact_id: String) -> String:
	var def: Dictionary = get_def(artefact_id)
	if def.is_empty():
		return "???"
	return def["name"] as String


static func get_description(artefact_id: String) -> String:
	var def: Dictionary = get_def(artefact_id)
	if def.is_empty():
		return ""
	return def["desc"] as String


static func get_display_color(artefact_id: String) -> Color:
	var def: Dictionary = get_def(artefact_id)
	if def.is_empty():
		return Color(0.5, 0.5, 0.5)
	return def["color"] as Color


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for def: Dictionary in ARTEFACT_POOL:
		ids.append(def["id"] as String)
	return ids


static func is_valid(artefact_id: String) -> bool:
	return not get_def(artefact_id).is_empty()
