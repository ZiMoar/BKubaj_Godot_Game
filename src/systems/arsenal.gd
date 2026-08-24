class_name Arsenal
extends RefCounted

## Central Compendium catalog — the single source of truth for the
## in-menu browser showing every weapon, relic, and enemy the player can meet.
##
## The browser (ArsenalMenu) reads this class; adding a new weapon/relic/enemy
## means adding one entry here (or to the pools it reads), and it appears in
## the menu automatically.
##
## Categories: "weapons", "relics", "enemies", "legend".

const CATEGORY_WEAPONS: String = "weapons"
const CATEGORY_RELICS: String = "relics"
const CATEGORY_ENEMIES: String = "enemies"
const CATEGORY_LEGEND: String = "legend"


static func categories() -> Array[String]:
	return [CATEGORY_WEAPONS, CATEGORY_RELICS, CATEGORY_ENEMIES, CATEGORY_LEGEND]


static func category_title(cat: String) -> String:
	match cat:
		CATEGORY_WEAPONS: return "Weapons"
		CATEGORY_RELICS: return "Relics"
		CATEGORY_ENEMIES: return "Enemies"
		CATEGORY_LEGEND: return "Mechanics"
	return "?"


## Every entry is a Dictionary: { name, subtitle, desc, color }.
## subtitle = one-line stat summary; desc = longer flavour/mechanics text.
static func entries(cat: String) -> Array[Dictionary]:
	match cat:
		CATEGORY_WEAPONS: return _weapons()
		CATEGORY_RELICS: return _relics()
		CATEGORY_ENEMIES: return _enemies()
		CATEGORY_LEGEND: return _legend()
	return []


# --- Weapons ----------------------------------------------------------------

static func _weapons() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var gold := Color(1.0, 0.85, 0.35)

	# Class primaries
	list.append({
		"name": "Knight Blade",
		"subtitle": "Sword · primary · 0.7s",
		"desc": "A broadsword with a 3-hit combo: two wide 100° slashes then a 1.5× stab. Physical damage.",
		"color": gold,
	})
	list.append({
		"name": "Arcane Bolts",
		"subtitle": "Magic · primary · 1.4s",
		"desc": "Fires a 3-bolt volley toward your cursor with gentle homing. Arcane — hits make enemies crit-vulnerable.",
		"color": gold,
	})
	list.append({
		"name": "Longbow",
		"subtitle": "Bow · primary · 0.65s",
		"desc": "A 3-step combo that cycles 1, then 2, then 3 arrows spread in a shallow fan. Arrows pierce and chain. Plus-Projectile anvil upgrades don't add bow arrows — instead they feed the Ranger's Rain of Arrows, making the volley hit harder. Physics damage.",
		"color": gold,
	})

	# Class secondaries / abilities
	list.append({
		"name": "Tower Shield",
		"subtitle": "Defense · secondary · 4s",
		"desc": "Raise a shield: blocks damage, grants armor and pushes enemies back. Knight's right-click ability.",
		"color": gold,
	})
	list.append({
		"name": "Mana Overload",
		"subtitle": "Buff · secondary · 8s",
		"desc": "Halves all cooldowns for a few seconds. Mage's right-click ability.",
		"color": gold,
	})
	list.append({
		"name": "Rain of Arrows",
		"subtitle": "AoE · secondary · 4s",
		"desc": "Rains arrows over a wide radius. Ranger's right-click ability. Scales with the Longbow's \"+Projectile\" upgrades: each extra projectile adds another arrow's worth of damage to the volley.",
		"color": gold,
	})

	# Rogue loadout
	list.append({
		"name": "Dual Stab",
		"subtitle": "Dagger · primary · 0.55s",
		"desc": "A fast dual stab — one at your cursor, one at the nearest enemy. Critical hits shorten your next cooldown. Physical damage.",
		"color": gold,
	})
	list.append({
		"name": "Smoke Bomb",
		"subtitle": "Stealth · secondary · 10s",
		"desc": "Drops a cloud of smoke that boosts your dodge chance and blinds enemies inside it.",
		"color": gold,
	})

	# Berserker loadout
	list.append({
		"name": "Spin Axe",
		"subtitle": "Melee · primary · 1.0s",
		"desc": "Spins a great axe through a wide arc — the outer edge strikes for double damage.",
		"color": gold,
	})
	list.append({
		"name": "Axe Throw",
		"subtitle": "Thrown · secondary · 4s",
		"desc": "Hurls a heavy bouncing axe. Its damage and element follow your Spin Axe.",
		"color": gold,
	})

	# Engineer loadout
	list.append({
		"name": "Grenade Launcher",
		"subtitle": "Ranged · primary · 0.85s",
		"desc": "Lobs arcing grenades that explode for fire damage in an area.",
		"color": gold,
	})
	list.append({
		"name": "Deploy Turret",
		"subtitle": "Deploy · secondary · 6s",
		"desc": "Deploys an auto-firing turret that lobs grenades for fire damage.",
		"color": gold,
	})

	# Automatic weapons (from the chest pool)
	for w: Dictionary in WeaponChoiceMenu.AUTO_WEAPON_POOL:
		list.append({
			"name": w["name"] as String,
			"subtitle": "Automatic · %.1fs" % float(w["cooldown"]),
			# The compendium can carry deeper mechanic notes via compendium_desc
			# (kept off the in-game tooltip); fall back to the short desc.
			"desc": (w["compendium_desc"] as String) if w.has("compendium_desc") else (w["desc"] as String),
			"color": gold,
		})
	return list


# --- Relics -----------------------------------------------------------------

static func _relics() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for def: Dictionary in Artefact.ARTEFACT_POOL:
		list.append({
			"name": def["name"] as String,
			"subtitle": "Relic",
			"desc": def["desc"] as String,
			"color": def["color"] as Color,
		})
	return list


# --- Enemies ----------------------------------------------------------------

static func _enemies() -> Array[Dictionary]:
	return [
		{
			"name": "Skeleton",
			"subtitle": "Swarmer · 50 HP",
			"desc": "The basic skeleton: melee only, average speed. Appears from the very first stage.",
			"color": Color(0.85, 0.85, 0.9),
		},
		{
			"name": "Bat",
			"subtitle": "Dasher · 30 HP",
			"desc": "Tiny and fragile, but fast — weaves in at high speed in swarms.",
			"color": Color(0.7, 0.7, 0.85),
		},
		{
			"name": "Skeleton Brute",
			"subtitle": "Tank · 140 HP",
			"desc": "Slow and armored. Soaks up damage and hits hard up close. Needs higher difficulty to spawn.",
			"color": Color(0.85, 0.55, 0.5),
		},
		{
			"name": "Bomber Skeleton",
			"subtitle": "Bomb · 120 HP",
			"desc": "Charges toward you and detonates for massive area damage. No contact damage — at a distance it's harmless.",
			"color": Color(1.0, 0.6, 0.2),
		},
		{
			"name": "Skeleton Archer",
			"subtitle": "Trooper · 45 HP",
			"desc": "Keeps its distance and fires arrows at you. Prioritize it before it wears you down.",
			"color": Color(0.6, 0.8, 0.65),
		},
		{
			"name": "Skeleton Necromancer",
			"subtitle": "Disruptor · 90 HP",
			"desc": "Summons reinforcements to swarm you. Dies quickly if you can reach it.",
			"color": Color(0.6, 0.6, 0.9),
		},
		{
			"name": "Skeleton General",
			"subtitle": "Boss · 4200 HP",
			"desc": "The end-of-stage boss. A huge HP pool tuned to a 5-minute fight and heavy contact damage.",
			"color": Color(0.9, 0.3, 0.3),
		},
	]


# --- Mechanics / legend -----------------------------------------------------

static func _legend() -> Array[Dictionary]:
	var t := DamageType.Type
	return [
		{
			"name": "Damage Types & Ailments",
			"subtitle": "Every hit has a damage type + ailment chance",
			"desc": "When a hit lands it rolls your Ailment Chance. On success it inflicts the ailment matching that hit's damage type.",
			"color": Color(1.0, 0.85, 0.35),
		},
		{
			"name": "Fire",
			"subtitle": "Type %d · Burn" % int(t.FIRE),
			"desc": "Burns — deals 30% of the hit per tick over 5 ticks. Keeps the strongest burn.",
			"color": Color(1.0, 0.45, 0.2),
		},
		{
			"name": "Lightning",
			"subtitle": "Type %d · Shock" % int(t.LIGHTNING),
			"desc": "Shocks — zaps a DIFFERENT nearby enemy for 50% of the hit.",
			"color": Color(1.0, 0.85, 0.2),
		},
		{
			"name": "Cold",
			"subtitle": "Type %d · Slow" % int(t.COLD),
			"desc": "Slows the enemy for a couple seconds.",
			"color": Color(0.45, 0.8, 1.0),
		},
		{
			"name": "Arcane",
			"subtitle": "Type %d · Crit Vulnerability" % int(t.ARCANE),
			"desc": "Makes non-crit hits against the enemy more likely to become crits.",
			"color": Color(0.85, 0.5, 1.0),
		},
		{
			"name": "Necrotic",
			"subtitle": "Type %d · Decay" % int(t.NECROTIC),
			"desc": "Decays the enemy — it deals 20% less damage for a while.",
			"color": Color(0.5, 0.9, 0.6),
		},
		{
			"name": "Holy",
			"subtitle": "Type %d · Brand" % int(t.HOLY),
			"desc": "Brands the enemy — it takes 1.5× damage from all sources for a while.",
			"color": Color(1.0, 0.95, 0.75),
		},
		{
			"name": "Poison",
			"subtitle": "Type %d · Stacking Poison" % int(t.POISON),
			"desc": "Poison — stacks up to 10, each stack deals 10% of the hit per slow tick over a long duration.",
			"color": Color(0.5, 0.85, 0.35),
		},
		{
			"name": "Physical",
			"subtitle": "Type %d · Impale" % int(t.PHYSICAL),
			"desc": "Impales — stores 30% of the hit and releases it all on the enemy's NEXT hit taken.",
			"color": Color(0.85, 0.85, 0.85),
		},
		{
			"name": "Difficulty",
			"subtitle": "How stages ramp up",
			"desc": "Difficulty grows over time and persists across stages. It scales enemy health, damage and speed, and gates which enemy types can spawn.",
			"color": Color(0.85, 0.7, 0.35),
		},
		{
			"name": "Elemental Anvil",
			"subtitle": "Re-forges a weapon's damage type",
			"desc": "A rare anvil that only converts a weapon's damage type — no stat boosts. Scaling rolls are light, so it's purely about which ailment you want on that weapon.",
			"color": Color(0.4, 0.65, 0.95),
		},
		{
			"name": "Inverted Anvil",
			"subtitle": "Trades a stat away for a payoff",
			"desc": "A corrupt anvil that gives negative stats in exchange for a bonus — slower projectiles, shorter range, fewer projectiles (with +25% damage to compensate), less area, less pierce or fewer chains. High risk, high reward.",
			"color": Color(0.8, 0.35, 0.6),
		},
		{
			"name": "Winged Boots",
			"subtitle": "Dash-only upgrades",
			"desc": "Pick 1 of 3 upgrades: an extra dash charge, 25% faster charge recovery, or 30% longer dashes. Purely mobility — damage-after-dash effects stay on relics.",
			"color": Color(0.6, 0.8, 1.0),
		},
		{
			"name": "Healing Pickups",
			"subtitle": "25%, half, or full heal",
			"desc": "Collectable runes that restore 25%, 50% or 100% of your max health. Rarer versions restore more.",
			"color": Color(0.35, 0.9, 0.5),
		},
		{
			"name": "Shop",
			"subtitle": "Spend gold at pedestals",
			"desc": "A merchant who lets you spend gold to spawn items: a +1 level, an anvil, a special reward (elemental/inverted anvil, Winged Boots, or golden anvil), and healing. Bigger heals are more cost-effective.",
			"color": Color(0.95, 0.78, 0.3),
		},
		{
			"name": "Golden Anvil",
			"subtitle": "Guaranteed signature upgrade",
			"desc": "The rarest anvil. Guarantees a signature upgrade for your weapon. Occasionally found in shops or special rooms.",
			"color": Color(0.95, 0.72, 0.22),
		},
	]
