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
		"id": "greed_to_xp",
		"name": "Enlightened Greed",
		"desc": "Gold gained also grants 25% of its value as XP.",
		"color": Color(0.85, 0.9, 0.4),
	},
	{
		"id": "cold_blooded",
		"name": "Cold Blooded",
		"desc": "Enemies afflicted with Slow take 30% more damage from you.",
		"color": Color(0.5, 0.75, 0.95),
	},
	{
		"id": "static_conduit",
		"name": "Static Conduit",
		"desc": "Your critical hits deal +50% damage to Shocked enemies.",
		"color": Color(0.95, 0.85, 0.2),
	},
	{
		"id": "cinder_propagation",
		"name": "Cinder Propagation",
		"desc": "When a Burning enemy dies, it ignites nearby enemies.",
		"color": Color(1.0, 0.55, 0.2),
	},
	{
		"id": "corrosive_burst",
		"name": "Corrosive Burst",
		"desc": "When Poison stacks expire, they explode for their remaining damage.",
		"color": Color(0.35, 0.85, 0.4),
	},
	{
		"id": "crimson_echo",
		"name": "Crimson Echo",
		"desc": "Impale lasts for 2 hits instead of releasing all at once.",
		"color": Color(0.85, 0.25, 0.35),
	},
	{
		"id": "brand_of_ruin",
		"name": "Brand of Ruin",
		"desc": "Branded enemies spread their Brand to nearby enemies on death.",
		"color": Color(1.0, 0.85, 0.7),
	},
	{
		"id": "momentum",
		"name": "Momentum",
		"desc": "After a Dash, your damage is +50% for 1 second.",
		"color": Color(0.75, 0.75, 0.95),
	},
	{
		"id": "ghost_step",
		"name": "Ghost Step",
		"desc": "While a Dash charge is ready, you have +20% Evasion.",
		"color": Color(0.6, 0.85, 0.95),
	},
	{
		"id": "second_wind",
		"name": "Second Wind",
		"desc": "Revives have a 50% chance to not be consumed.",
		"color": Color(0.8, 0.7, 0.95),
	},
	{
		"id": "unstable_mind",
		"name": "Unstable Mind",
		"desc": "Critically Vulnerable enemies have +50% chance to catch your ailments.",
		"color": Color(0.85, 0.6, 0.9),
	},
	{
		"id": "soul_harvest",
		"name": "Soul Harvest",
		"desc": "Enemies leave behind souls. Collecting one grants a Shield equal to 5% of your Max Health.",
		"color": Color(0.45, 0.9, 0.75),
	},
	{
		"id": "regen_to_shield",
		"name": "Regen Overload",
		"desc": "HP Regen that would heal you past full health instead grants Shield.",
		"color": Color(0.5, 0.8, 1.0),
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
