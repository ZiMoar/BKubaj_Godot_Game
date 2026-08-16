class_name AnvilUpgradeMenu
extends Control

## Anvil upgrade menu. Two phases:
##   1. Pick which weapon to upgrade.
##   2. Pick 1 of 3 stat upgrades from the anvil stat pool, filtered to the
##      stats that weapon actually supports (projectile count, pierce, chain,
##      area). These stats are NOT available from level-ups.

signal upgrade_applied(weapon: Weapon, stat_id: String)

# The anvil stat pool. Each entry knows how to apply itself to a Weapon node.
# "weight" governs how likely an entry is to be rolled vs others (higher = more
# common). Damage-type conversions are half-weighted so they appear less often.
var STAT_POOL: Array[Dictionary] = [
	{
		"id": "projectile_count",
		"title": "Projectile Count",
		"description": "+{value} projectile(s).",
		"value": 1,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.projectile_count_bonus += 1,
	},
	{
		"id": "pierce",
		"title": "Pierce",
		"description": "+{value} pierce.",
		"value": 1,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.pierce_bonus += 1,
	},
	{
		"id": "chain",
		"title": "Chain",
		"description": "+{value} chain.",
		"value": 1,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.chain_count_bonus += 1,
	},
	{
		"id": "area",
		"title": "Area",
		"description": "+{value}% skill & projectile size.",
		"value": 10,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.area_bonus += 0.10,
	},
	{
		"id": "repeat",
		"title": "Repeat",
		"description": "+{value}% repeat chance. Each 100% guarantees an extra volley; leftover is % chance of another.",
		"value": 25,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.repeat_chance += 0.25,
	},
	{
		"id": "projectile_speed",
		"title": "Projectile Speed",
		"description": "+{value}% projectile travel speed.",
		"value": 30,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.projectile_speed_bonus += 0.30,
	},
	{
		"id": "close_range_damage",
		"title": "Close Range",
		"description": "+{value}% damage to enemies near you.",
		"value": 40,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.close_range_damage_bonus += 0.40,
	},
	{
		"id": "explosion_on_kill",
		"title": "Explosion on Kill",
		"description": "{value}% chance kills explode in an AOE (100% = always, extra % = chance of a 2nd explosion).",
		"value": 25,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.explosion_on_kill_chance += 0.25,
	},
	{
		"id": "duration",
		"title": "Duration",
		"description": "+{value}% effect duration.",
		"value": 20,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.duration_bonus += 0.20,
	},
	{
		"id": "knockback",
		"title": "Knockback",
		"description": "+{value}% enemy pushback.",
		"value": 40,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.knockback_bonus += 0.40,
	},
	{
		"id": "ailment_effect",
		"title": "Ailment Effect",
		"description": "+{value}% ailment potency (burn/poison/slow/impale/shock).",
		"value": 30,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.ailment_effect_bonus += 0.30,
	},
]

## Elemental anvil pool: ONLY damage-type conversion stats. This anvil is a
## separate pickup (new room types); normal anvils never roll these anymore.
var ELEMENTAL_STAT_POOL: Array[Dictionary] = [
	{
		"id": "element_fire",
		"title": "Fire Damage",
		"description": "Convert damage to FIRE.",
		"value": 0,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.FIRE,
	},
	{
		"id": "element_lightning",
		"title": "Lightning Damage",
		"description": "Convert damage to LIGHTNING.",
		"value": 0,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.LIGHTNING,
	},
	{
		"id": "element_cold",
		"title": "Cold Damage",
		"description": "Convert damage to COLD.",
		"value": 0,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.COLD,
	},
	{
		"id": "element_arcane",
		"title": "Arcane Damage",
		"description": "Convert damage to ARCANE.",
		"value": 0,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.ARCANE,
	},
	{
		"id": "element_necrotic",
		"title": "Necrotic Damage",
		"description": "Convert damage to NECROTIC.",
		"value": 0,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.NECROTIC,
	},
	{
		"id": "element_holy",
		"title": "Holy Damage",
		"description": "Convert damage to HOLY.",
		"value": 0,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.HOLY,
	},
	{
		"id": "element_poison",
		"title": "Poison Damage",
		"description": "Convert damage to POISON.",
		"value": 0,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.POISON,
	},
]

## Inverted anvil pool: the "give something up" stats. Trades negatives for a
## payoff. Far Range lives here (an odd stat that rewards keeping distance), plus
## new reduce-AOE / reduce-projectiles(+damage comp) / reduce-pierce / reduce-chain.
var INVERTED_STAT_POOL: Array[Dictionary] = [
	{
		"id": "projectile_speed_down",
		"title": "Slow Projectiles",
		"description": "-{value}% projectile travel speed.",
		"value": 30,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.projectile_speed_bonus -= 0.30,
	},
	{
		"id": "duration_shorten",
		"title": "Shorter Duration",
		"description": "-{value}% effect duration.",
		"value": 25,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.duration_bonus -= 0.25,
	},
	{
		"id": "far_range_damage",
		"title": "Far Range",
		"description": "+{value}% damage to distant enemies.",
		"value": 40,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.far_range_damage_bonus += 0.40,
	},
	{
		"id": "area_down",
		"title": "Shrink Area",
		"description": "-{value}% skill & projectile size.",
		"value": 10,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.area_bonus -= 0.10,
	},
	{
		"id": "projectile_count_down",
		"title": "Fewer Projectiles",
		"description": "-{value} projectile(s), but +25% damage each.",
		"value": 1,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void:
			w.projectile_count_bonus = maxi(-1, w.projectile_count_bonus - 1)
			w.damage_percent_bonus += 0.25,
	},
	{
		"id": "pierce_down",
		"title": "Less Pierce",
		"description": "-{value} pierce.",
		"value": 1,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.pierce_bonus -= 1,
	},
	{
		"id": "chain_down",
		"title": "Less Chain",
		"description": "-{value} chain.",
		"value": 1,
		"weight": 1.0,
		"apply": func(w: Weapon) -> void: w.chain_count_bonus -= 1,
	},
]

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var weapon_list: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical/WeaponScroll/WeaponList") as VBoxContainer
@onready var weapon_scroll: ScrollContainer = get_node_or_null("CenterContainer/Panel/Vertical/WeaponScroll") as ScrollContainer
@onready var stat_box: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical/StatBox") as VBoxContainer
@onready var choice_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/Choice1") as Button
@onready var choice_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/Choice2") as Button
@onready var choice_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/Choice3") as Button
@onready var back_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/BottomRow/BackButton") as Button
@onready var reroll_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/BottomRow/RerollButton") as Button

var rng := RandomNumberGenerator.new()
var _current_player: Player = null
var _selected_weapon: Weapon = null
var _current_stats: Array[Dictionary] = []
var _rerolls_done: int = 0
## Golden anvils (5% of spawns) guarantee at least one signature upgrade choice.
var _is_golden: bool = false

## What kind of anvil opened this menu: STANDARD rolls the normal stat pool (with
## signatures/golden), ELEMENTAL rolls only damage-type conversions, INVERTED
## rolls the negative/"give something up" stats. Set by open_menu(kind).
enum AnvilKind { STANDARD, ELEMENTAL, INVERTED }
var _anvil_kind: int = AnvilKind.STANDARD

## Golden border/destructive styling used to flag signature upgrade choices so a
## player can tell at a glance that a signature mod rolled (vs a normal stat).
const SIG_BORDER_COLOR: Color = Color(1.0, 0.84, 0.25)
const SIG_TEXT_COLOR: Color = Color(1.0, 0.9, 0.4)
const SIG_BG_COLOR: Color = Color(0.35, 0.28, 0.08, 0.92)

## Elemental anvil mods get a blue outline so they read as damage-type reforges.
const ELEM_BORDER_COLOR: Color = Color(0.4, 0.65, 0.95)
const ELEM_TEXT_COLOR: Color = Color(0.72, 0.85, 1.0)
const ELEM_BG_COLOR: Color = Color(0.08, 0.16, 0.35, 0.92)

## Inverted anvil mods get a purple outline so they read as "give something up".
const INV_BORDER_COLOR: Color = Color(0.75, 0.35, 0.6)
const INV_TEXT_COLOR: Color = Color(1.0, 0.75, 0.95)
const INV_BG_COLOR: Color = Color(0.28, 0.08, 0.3, 0.92)

const REROLL_BASE_COST: int = 50


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	visible = false
	_bind_buttons()
	# Constrain the menu to the viewport so long stat/choice text can't push the
	# panel off-screen. We center it and cap its width (done in code so the .tscn
	# offsets don't fight the runtime theme).
	_fit_panel_to_viewport()


## Re-centers the anvil menu and caps its panel width to the viewport, so long
## choice descriptions never make the menu wider than the screen.
func _fit_panel_to_viewport() -> void:
	var cc: Control = get_node_or_null("CenterContainer") as Control
	if cc:
		cc.anchor_left = 0.0
		cc.anchor_top = 0.0
		cc.anchor_right = 1.0
		cc.anchor_bottom = 1.0
		cc.offset_left = 0.0
		cc.offset_top = 0.0
		cc.offset_right = 0.0
		cc.offset_bottom = 0.0
		cc.grow_horizontal = Control.GROW_DIRECTION_BOTH
		cc.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel: Control = get_node_or_null("CenterContainer/Panel") as Control
	if panel:
		var vp: Vector2 = get_viewport_rect().size
		var max_w: float = maxf(240.0, vp.x * 0.92)
		# Cap BOTH width and height so a tall stat-selection stack (3 choice
		# buttons + bottom row) never overflows the viewport's design height and
		# pushes Reroll below the screen.
		var max_h: float = maxf(200.0, vp.y * 0.9)
		panel.custom_minimum_size = Vector2(
			minf(panel.custom_minimum_size.x, max_w),
			minf(panel.custom_minimum_size.y, max_h)
		)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Choice buttons should clip (ellipsis) rather than widen the panel, and be
	# capped so long text can never push the panel off-screen.
	var cap_w: float = maxf(220.0, get_viewport_rect().size.x * 0.85)
	for b: Button in [choice_1, choice_2, choice_3]:
		if b:
			button_clip(b, cap_w)


func _bind_buttons() -> void:
	if choice_1 and not choice_1.pressed.is_connected(_on_stat_pressed.bind(0)):
		choice_1.pressed.connect(_on_stat_pressed.bind(0))
	if choice_2 and not choice_2.pressed.is_connected(_on_stat_pressed.bind(1)):
		choice_2.pressed.connect(_on_stat_pressed.bind(1))
	if choice_3 and not choice_3.pressed.is_connected(_on_stat_pressed.bind(2)):
		choice_3.pressed.connect(_on_stat_pressed.bind(2))
	# The Back button is intentionally DISABLED (both normal and golden anvils):
	# once you pick a weapon to upgrade, you commit to an upgrade. Prevents
	# farming the menu to re-roll weapon picks for free.
	if back_button:
		back_button.visible = false
		back_button.disabled = true
		back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reroll_button and not reroll_button.pressed.is_connected(_on_reroll_pressed):
		reroll_button.pressed.connect(_on_reroll_pressed)


func open_menu(golden: bool = false, kind: int = AnvilKind.STANDARD) -> void:
	_current_player = get_tree().get_first_node_in_group("player") as Player
	if _current_player == null:
		return
	_is_golden = golden
	_anvil_kind = kind
	visible = true
	_show_weapon_selection()


func close_menu() -> void:
	visible = false
	_selected_weapon = null
	_current_stats = []


func _get_player_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	var container: Node = _current_player.get_node_or_null("Weapons") if _current_player else null
	if container:
		for w: Node in container.get_children():
			if w is Weapon:
				# Exclude right-click (secondary) abilities from the anvil: they
				# inherit their upgrades from the primary weapon instead.
				if w.trigger_type == Weapon.TriggerType.SECONDARY:
					continue
				result.append(w as Weapon)
	return result


## Anti-stacking gate: a weapon may only be raised past a multiple of 3 once
## every weapon the player owns has reached that multiple. Returns the highest
## upgrade level (0-indexed count) any single weapon may currently be raised TO,
## i.e. floor(min_upgrades/3)*3 + 3. Example: all at 0-2 -> max 3; all at 3-5 ->
## max 6; all at 6+ -> max 9 (and so on).
func _get_max_anvil_level(weapons: Array[Weapon]) -> int:
	if weapons.is_empty():
		return 0
	var min_upgrades: int = 1 << 30
	for w: Weapon in weapons:
		min_upgrades = mini(min_upgrades, w.anvil_upgrade_count)
	return (min_upgrades / 3) * 3 + 3


# --- Phase 1: weapon selection -------------------------------------------

func _show_weapon_selection() -> void:
	if weapon_list == null:
		return
	# Build weapon buttons
	for child: Node in weapon_list.get_children():
		child.queue_free()

	var weapons: Array[Weapon] = _get_player_weapons()
	if weapons.is_empty():
		close_menu()
		return

	var max_level: int = _get_max_anvil_level(weapons)
	var any_locked: bool = false
	for w: Weapon in weapons:
		var btn := Button.new()
		btn.text = w.weapon_name
		if w.anvil_upgrade_count >= max_level:
			btn.text = "%s  (locked)" % w.weapon_name
			btn.disabled = true
			any_locked = true
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_weapon_pressed.bind(w))
		weapon_list.add_child(btn)

	if title_label:
		match _anvil_kind:
			AnvilKind.ELEMENTAL:
				title_label.text = "Elemental Anvil"
			AnvilKind.INVERTED:
				title_label.text = "Inverted Anvil"
			_:
				title_label.text = "Golden Anvil" if _is_golden else "The Anvil"
	if subtitle_label:
		match _anvil_kind:
			AnvilKind.ELEMENTAL:
				subtitle_label.text = "Choose a weapon. Guarantees a damage-type reforge, plus standard upgrades."
			AnvilKind.INVERTED:
				subtitle_label.text = "Choose a weapon. Guarantees an inverted trade, plus standard upgrades."
			_:
				subtitle_label.text = "Choose a weapon to upgrade. Grants a signature choice!" if _is_golden else "Choose a weapon to upgrade."
	if any_locked and subtitle_label:
		subtitle_label.text += "\nIt's locked: spread anvil upgrades across every weapon to push one past 3."
	weapon_list.visible = true
	if weapon_scroll:
		weapon_scroll.visible = true
	if stat_box:
		stat_box.visible = false


func _on_weapon_pressed(weapon: Weapon) -> void:
	_selected_weapon = weapon
	_rerolls_done = 0
	_show_stat_selection()


# --- Phase 2: stat selection ---------------------------------------------

func _show_stat_selection() -> void:
	if _selected_weapon == null:
		return
	_current_stats = _roll_stats(_selected_weapon)

	if subtitle_label:
		subtitle_label.text = "Choose an upgrade for %s." % _selected_weapon.weapon_name
	if weapon_list:
		weapon_list.visible = false
	if weapon_scroll:
		# The weapon list scroll region has a 120px min-height; hiding it while the
		# stat choices are shown keeps the panel short enough to fit on-screen so
		# the bottom row (Reroll) is never pushed below the viewport.
		weapon_scroll.visible = false
	if stat_box:
		stat_box.visible = true

	_update_stat_buttons()
	_update_reroll_ui()


func _roll_stats(weapon: Weapon) -> Array[Dictionary]:
	# The normal anvil stat pool (filtered to what this weapon supports). Shared by
	# all anvil kinds that can roll standard upgrades.
	var normal_pool: Array[Dictionary] = []
	for stat: Dictionary in STAT_POOL:
		if _weapon_supports(weapon, stat["id"] as String):
			normal_pool.append(stat)

	# Elemental / inverted anvils guarantee at least one mod from their own pool,
	# but ALSO roll from the standard pool to fill out the rest of the choices.
	if _anvil_kind == AnvilKind.ELEMENTAL:
		return _roll_special(normal_pool, _filter_supported(weapon, ELEMENTAL_STAT_POOL))
	if _anvil_kind == AnvilKind.INVERTED:
		return _roll_special(normal_pool, _filter_supported(weapon, INVERTED_STAT_POOL))

	# Remaining (not-yet-taken) signature upgrades for this weapon.
	var sig_pool: Array[Dictionary] = []
	for sig: Dictionary in weapon.get_signature_pool():
		if weapon.has_signature(sig.get("id", "")):
			continue
		var entry := sig.duplicate()
		entry["weight"] = weapon.get_signature_weight()
		sig_pool.append(entry)

	# Golden anvil: exactly one signature guaranteed among the three choices.
	if _is_golden:
		if not sig_pool.is_empty():
			return _roll_golden(normal_pool, sig_pool)
		# FAILSAFE: the weapon already owns all its signatures, so the golden anvil
		# falls back to a normal 3-stat roll.
		return _roll_stats_normal(normal_pool)

	# Normal anvil: signatures appear only ~1% of the time. When the 1% hits, one
	# signature is guaranteed in the choices; otherwise pure standard stats.
	if not sig_pool.is_empty() and rng.randf() < 0.01:
		return _roll_golden(normal_pool, sig_pool)
	return _roll_stats_normal(normal_pool)


## Picks 3 distinct stats purely by weight (no signature guarantee). Used for
## normal anvils, and as the golden failsafe when no signatures remain.
func _roll_stats_normal(pool: Array[Dictionary]) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	while choices.size() < 3 and not pool.is_empty():
		var index: int = _weighted_pick(pool)
		choices.append(pool[index])
		pool.remove_at(index)
	return choices


## Special anvils (elemental/inverted): guarantee at least one mod from their own
## pool, then fill the remaining choices from a combined pool that also includes
## the standard anvil stats — so they can roll normal mods too.
func _roll_special(normal_pool: Array[Dictionary], special_pool: Array[Dictionary]) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	# Guarantee one mod from the special pool.
	if not special_pool.is_empty():
		var s_idx: int = _weighted_pick(special_pool)
		choices.append(special_pool[s_idx])
		special_pool.remove_at(s_idx)
	else:
		# No special mod is supported (rare); just fall back to standard stats.
		return _roll_stats_normal(normal_pool)
	# Fill the remaining 2 choices from normal + leftover special stats.
	var combined: Array[Dictionary] = normal_pool + special_pool
	while choices.size() < 3 and not combined.is_empty():
		var idx: int = _weighted_pick(combined)
		choices.append(combined[idx])
		combined.remove_at(idx)
	choices.shuffle()
	return choices


## Returns only the stats in the given pool that the weapon supports. Used for
## the elemental/inverted anvil pools which share the same capability checks.
func _filter_supported(weapon: Weapon, pool: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stat: Dictionary in pool:
		if _weapon_supports(weapon, stat["id"] as String):
			result.append(stat)
	return result


## Golden anvil: exactly one guaranteed signature choice, plus two normal stats.
func _roll_golden(pool: Array[Dictionary], sig_pool: Array[Dictionary]) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	# 1 guaranteed signature (weighted pick among remaining signatures).
	var sig_idx: int = _weighted_pick(sig_pool)
	choices.append(sig_pool[sig_idx])
	sig_pool.remove_at(sig_idx)
	# 2 normal stats (no signatures to keep the choice clean and distinct).
	var normal_pool: Array[Dictionary] = pool.duplicate()
	var count: int = 0
	while count < 2 and not normal_pool.is_empty():
		var index: int = _weighted_pick(normal_pool)
		choices.append(normal_pool[index])
		normal_pool.remove_at(index)
		count += 1
	# Shuffle so the signature isn't always first.
	choices.shuffle()
	return choices


## Weighted random pick from a pool of stat dicts (entries carry a "weight").
## Skimpy entries (e.g. damage-type conversion at 0.5) appear less often.
func _weighted_pick(pool: Array[Dictionary]) -> int:
	var total: float = 0.0
	for stat: Dictionary in pool:
		total += float(stat.get("weight", 1.0))
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for i: int in range(pool.size()):
		acc += float(pool[i].get("weight", 1.0))
		if roll < acc:
			return i
	return pool.size() - 1


func _weapon_supports(weapon: Weapon, stat_id: String) -> bool:
	match stat_id:
		"projectile_count":
			return weapon.supports_projectile_count()
		"pierce":
			return weapon.supports_pierce()
		"chain":
			return weapon.supports_chain()
		"area":
			return weapon.supports_area()
		"repeat":
			return weapon.supports_repeat()
		"projectile_speed", "projectile_speed_down":
			return weapon.supports_projectile_speed()
		"duration", "duration_shorten":
			return weapon.supports_duration()
		"close_range_damage", "far_range_damage":
			# Close/Far Range are available to EVERY weapon (no projectile/range
			# restriction) — distance-based damage works on melee and ranged alike.
			return true
		"area_down":
			return weapon.supports_area()
		"projectile_count_down":
			return weapon.supports_projectile_count()
		"pierce_down":
			return weapon.supports_pierce()
		"chain_down":
			return weapon.supports_chain()
		"explosion_on_kill":
			# Explosion on Kill works on any weapon that can land a kill.
			return true
		"knockback":
			return weapon.supports_knockback()
		"ailment_effect":
			return weapon.supports_ailment_effect()
		"element_fire", "element_lightning", "element_cold", "element_arcane", "element_necrotic", "element_holy", "element_poison":
			# Re-forging offered only for elements the weapon does NOT already hold.
			return weapon.damage_type != _element_damage_type(stat_id)
	return false


func _element_damage_type(stat_id: String) -> DamageType.Type:
	match stat_id:
		"element_fire": return DamageType.Type.FIRE
		"element_lightning": return DamageType.Type.LIGHTNING
		"element_cold": return DamageType.Type.COLD
		"element_arcane": return DamageType.Type.ARCANE
		"element_necrotic": return DamageType.Type.NECROTIC
		"element_holy": return DamageType.Type.HOLY
		"element_poison": return DamageType.Type.POISON
	return DamageType.Type.PHYSICAL


func get_current_reroll_cost() -> int:
	# Free rerolls on the test map (detected via TestFacilities presence).
	if get_tree().get_first_node_in_group("test_facilities") != null:
		return 0
	return REROLL_BASE_COST * (1 << _rerolls_done)


func _on_reroll_pressed() -> void:
	if _selected_weapon == null:
		return
	var player: Player = _current_player
	var cost: int = get_current_reroll_cost()
	if cost > 0 and (player == null or not player.can_afford(cost)):
		_update_reroll_ui()
		return
	if cost > 0 and not player.spend_gold(cost):
		_update_reroll_ui()
		return
	_rerolls_done += 1
	_current_stats = _roll_stats(_selected_weapon)
	_update_stat_buttons()
	_update_reroll_ui()


func _update_reroll_ui() -> void:
	if reroll_button == null:
		return
	var cost: int = get_current_reroll_cost()
	if cost == 0:
		reroll_button.text = "Reroll (free)"
		reroll_button.disabled = false
		return
	var player: Player = _current_player
	var affordable: bool = player != null and player.can_afford(cost)
	reroll_button.text = "Reroll (%dg)" % cost
	reroll_button.disabled = not affordable


func _update_stat_buttons() -> void:
	var buttons: Array[Button] = [choice_1, choice_2, choice_3]
	for i: int in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		if i >= _current_stats.size():
			button.text = "-"
			button.disabled = true
			_reset_choice_style(button)
			continue
		var stat: Dictionary = _current_stats[i]
		var desc: String = (stat["description"] as String).replace("{value}", "%d" % int(stat["value"]))
		var is_sig: bool = _is_signature_entry(stat)
		var title_text: String = stat["title"] as String
		if is_sig:
			# Plain gold-star glyph (Button.text does NOT parse [color] bbcode, so
			# we must not put a bbcode tag in a plain label). The golden look
			# comes from the border/text style applied by _apply_signature_style.
			title_text = "✦ %s" % title_text
		button.text = "%s\n%s" % [title_text, desc]
		button.disabled = false
		# Clear any styling a PREVIOUS roll/kind left on this reused button node
		# (e.g. the elemental blue or inverted purple border/focus/pressed colors).
		# Without this, a normal stat that lands in a slot which earlier held an
		# elemental mod can keep a blue border — colors leaking onto mods that
		# shouldn't have them. Must happen BEFORE applying the new branch style.
		_reset_choice_style(button)
		# Signature choices get a prominent golden border so they read as special;
		# elemental mods get a blue outline and inverted mods a purple outline;
		# normal stats keep the standard purple tint (no border).
		if _is_signature_entry(stat):
			_apply_signature_style(button)
		elif _is_elemental_entry(stat):
			_apply_outline_style(button, ELEM_BORDER_COLOR, ELEM_BG_COLOR, ELEM_TEXT_COLOR)
		elif _is_inverted_entry(stat):
			_apply_outline_style(button, INV_BORDER_COLOR, INV_BG_COLOR, INV_TEXT_COLOR)
		else:
			button.modulate = Color(0.85, 0.7, 0.95)
			button.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
			button.add_theme_color_override("font_hover_color", Color.WHITE)


## Removes every style/font override a choice button may carry from an
## elemental, inverted, or signature roll, so reusing the button for a different
## kind of mod never leaks a stale border or text color. Called on every stat
## button before its current branch style is applied.
func _reset_choice_style(button: Button) -> void:
	if button == null:
		return
	button.modulate = Color.WHITE
	for sb in ["normal", "hover", "pressed", "focus"]:
		button.remove_theme_stylebox_override(sb)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.remove_theme_color_override(fc)


func _on_stat_pressed(index: int) -> void:
	if index < 0 or index >= _current_stats.size() or _selected_weapon == null:
		return
	var stat: Dictionary = _current_stats[index]
	# Signature entries carry an "id"; route them through apply_signature so the
	# weapon records it as taken (once-per-run), then emit with a sig prefix.
	if stat.has("id") and _is_signature_entry(stat):
		_selected_weapon.apply_signature(stat)
		upgrade_applied.emit(_selected_weapon, "signature:" + str(stat["id"]))
		return
	var apply: Callable = stat["apply"] as Callable
	apply.call(_selected_weapon)
	_selected_weapon.anvil_upgrade_count += 1
	upgrade_applied.emit(_selected_weapon, stat["id"] as String)


## Configures a Button to ellipsize overflow text instead of growing the panel.
## clip_text stops the button's minimum size from tracking the full text width,
## so the panel can't be pushed off-screen by a long description. cap_w is only
## used as a sane floor for the button's minimum if sized from the .tscn.
func button_clip(button: Button, cap_w: float) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	if button.custom_minimum_size.x < 1.0:
		button.custom_minimum_size = Vector2(cap_w, button.custom_minimum_size.y)


## Styles a button as a special golden SIGNATURE upgrade with a gold border and
## gold text so players instantly spot that a signature mod rolled.
func _apply_signature_style(button: Button) -> void:
	_apply_outline_style(button, SIG_BORDER_COLOR, SIG_BG_COLOR, SIG_TEXT_COLOR)


## Applies a colored outline (border) to a choice button, used to tell elemental
## (blue) and inverted (purple) mods apart from normal and signature mods.
func _apply_outline_style(button: Button, border_color: Color, bg_color: Color, text_color: Color) -> void:
	button.modulate = Color.WHITE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = bg_color.lightened(0.2)
	sb_hover.border_color = border_color.lightened(0.35)
	sb_hover.set_border_width_all(4)
	sb_hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb_hover)
	button.add_theme_stylebox_override("pressed", sb_hover)
	button.add_theme_stylebox_override("focus", sb)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.3))
	button.add_theme_color_override("font_pressed_color", text_color.lightened(0.3))


## A stat is a signature if it came from a weapon's signature pool. The simplest
## robust check: signature ids are never valid normal stat ids, and we flag them
## by looking it up in the weapon's signature pool.
func _is_signature_entry(stat: Dictionary) -> bool:
	if _selected_weapon == null:
		return false
	for sig: Dictionary in _selected_weapon.get_signature_pool():
		if sig.get("id", "") == stat.get("id", ""):
			return true
	return false


## A stat is an ELEMENTAL mod if its id belongs to the elemental anvil pool.
func _is_elemental_entry(stat: Dictionary) -> bool:
	return _stat_in_pool(stat, ELEMENTAL_STAT_POOL)


## A stat is an INVERTED mod if its id belongs to the inverted anvil pool.
func _is_inverted_entry(stat: Dictionary) -> bool:
	return _stat_in_pool(stat, INVERTED_STAT_POOL)


func _stat_in_pool(stat: Dictionary, pool: Array[Dictionary]) -> bool:
	var id: String = stat.get("id", "")
	if id.is_empty():
		return false
	for s: Dictionary in pool:
		if s.get("id", "") == id:
			return true
	return false


func _on_back_pressed() -> void:
	_selected_weapon = null
	_current_stats = []
	_show_weapon_selection()