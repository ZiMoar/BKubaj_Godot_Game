class_name DamageType
## Central enum of elemental damage types. Each weapon/projectile reports the
## type of damage it deals so a future ailment system can key off it (instead of
## every weapon being able to apply every DoT).
##
## PHYSICAL is the default for any weapon that does not specify an element.
## NECROTIC, LIGHT and POISON are reserved for content that does not exist yet,
## but the enum is declared now so the framework is ready for them.
enum Type {
	PHYSICAL,   # default — plain strikes (sword, dagger, arrows, spin blade, ...)
	FIRE,       # Fire Aura
	LIGHTNING,  # Lightning Bolt
	COLD,       # Frost Nova / ice
	ARCANE,     # Arcane Bolts (mage)
	NECROTIC,   # reserved (not yet used)
	LIGHT,      # reserved (not yet used)
	POISON,     # reserved (not yet used)
}
