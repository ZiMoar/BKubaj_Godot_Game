class_name DamageType
##########################################################################
## Elemental damage types. Every weapon/projectile reports the type of
## damage it deals; enemies roll "ailment chance" on each hit and inflict the
## ailment matching that damage type (see EnemyBase._apply_ailment).
##
## PHYSICAL is the default for weapons that do not specify an element.
## NECROTIC / HOLY / POISON have no dedicated weapon yet but are declared so the
## framework (and the anvil's damage-type upgrades) are ready for them.
##########################################################################
enum Type {
	PHYSICAL,   # default — impale (stores % of the hit, released on next hit)
	FIRE,       # burn (DoT scaled off the hit)
	LIGHTNING,  # shock (zap a nearby different enemy for 50% of the hit)
	COLD,       # slow
	ARCANE,     # crit vulnerability (more likely to be critically hit)
	NECROTIC,   # decay (enemy deals 20% less damage)
	HOLY,       # brand (enemy takes increased damage from all sources)
	POISON,     # stackable DoT (long duration, slow ticks, < burn magnitude)
	CHROMATIC,  # signals RANDOM-element behaviour (Chromatic Orb) — no fixed ailment
}


## Short display label for a damage type, e.g. "FIRE". Used by the compendium
## legend and the weapon slot HUD so builds read clearly at a glance.
static func display_name(type: Type) -> String:
	match type:
		Type.FIRE: return "FIRE"
		Type.LIGHTNING: return "LIGHTNING"
		Type.COLD: return "COLD"
		Type.ARCANE: return "ARCANE"
		Type.NECROTIC: return "NECROTIC"
		Type.HOLY: return "HOLY"
		Type.POISON: return "POISON"
		Type.CHROMATIC: return "CHROMATIC"
	return "PHYSICAL"


## A representative colour for each damage type, for HUD / tooltip accents.
static func color_for(type: Type) -> Color:
	match type:
		Type.FIRE: return Color(1.0, 0.45, 0.2)
		Type.LIGHTNING: return Color(1.0, 0.85, 0.2)
		Type.COLD: return Color(0.45, 0.8, 1.0)
		Type.ARCANE: return Color(0.85, 0.5, 1.0)
		Type.NECROTIC: return Color(0.5, 0.9, 0.6)
		Type.HOLY: return Color(1.0, 0.95, 0.75)
		Type.POISON: return Color(0.5, 0.85, 0.35)
		Type.CHROMATIC: return Color(1.0, 0.45, 0.75)
	return Color(0.85, 0.85, 0.85)


## Ailment / element keywords that appear in descriptions, mapped to the damage
## type whose colour they should be highlighted with. Longer, more specific
## forms ("burning", "decaying") are listed so they colour as one unit; regex
## word-boundaries prevent partial matches ("burn" won't touch "burning").
const AILMENT_KEYWORDS: Array = [
	["burning", Type.FIRE], ["burns", Type.FIRE], ["burn", Type.FIRE], ["fire", Type.FIRE],
	["poison", Type.POISON], ["toxic", Type.POISON],
	["shocked", Type.LIGHTNING], ["shocks", Type.LIGHTNING], ["shock", Type.LIGHTNING],
	["lightning", Type.LIGHTNING], ["electric", Type.LIGHTNING],
	["slowed", Type.COLD], ["slows", Type.COLD], ["slow", Type.COLD],
	["frozen", Type.COLD], ["freeze", Type.COLD], ["frost", Type.COLD], ["cold", Type.COLD],
	["critically", Type.ARCANE], ["crits", Type.ARCANE], ["crit", Type.ARCANE], ["arcane", Type.ARCANE],
	["decaying", Type.NECROTIC], ["decays", Type.NECROTIC], ["decay", Type.NECROTIC], ["necrotic", Type.NECROTIC],
	["branded", Type.HOLY], ["brands", Type.HOLY], ["brand", Type.HOLY], ["holy", Type.HOLY],
	["impaled", Type.PHYSICAL], ["impales", Type.PHYSICAL], ["impale", Type.PHYSICAL], ["physical", Type.PHYSICAL],
]


## Wraps ailment / element keywords in a description in BBCode [color] tags
## matching their element's colour, so players can see what element each effect
## belongs to. Renders correctly in Label, Button and RichTextLabel. Uses
## per-keyword regex so the original casing of each word is preserved.
static func colorize(text: String) -> String:
	var result := text
	for pair: Array in AILMENT_KEYWORDS:
		var word: String = pair[0] as String
		var type: Type = pair[1] as Type
		var re := RegEx.new()
		re.compile("(?i)\\b(" + word + ")\\b")
		result = re.sub(result, "[color=%s]$1[/color]" % color_for(type).to_html(false), true)
	return result
