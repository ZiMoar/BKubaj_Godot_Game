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
