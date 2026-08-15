class_name AnvilUpgradeMenu
extends Control

## Anvil upgrade menu. Two phases:
##   1. Pick which weapon to upgrade.
##   2. Pick 1 of 3 stat upgrades from the anvil stat pool, filtered to the
##      stats that weapon actually supports (projectile count, pierce, chain,
##      area). These stats are NOT available from level-ups.

signal upgrade_applied(weapon: Weapon, stat_id: String)

# The anvil stat pool. Each entry knows how to apply itself to a Weapon node.
var STAT_POOL: Array[Dictionary] = [
	{
		"id": "projectile_count",
		"title": "Projectile Count",
		"description": "+{value} projectile(s).",
		"value": 1,
		"apply": func(w: Weapon) -> void: w.projectile_count_bonus += 1,
	},
	{
		"id": "pierce",
		"title": "Pierce",
		"description": "+{value} pierce.",
		"value": 1,
		"apply": func(w: Weapon) -> void: w.pierce_bonus += 1,
	},
	{
		"id": "chain",
		"title": "Chain",
		"description": "+{value} chain.",
		"value": 1,
		"apply": func(w: Weapon) -> void: w.chain_count_bonus += 1,
	},
	{
		"id": "area",
		"title": "Area",
		"description": "+{value}% skill & projectile size.",
		"value": 10,
		"apply": func(w: Weapon) -> void: w.area_bonus += 0.10,
	},
	{
		"id": "repeat",
		"title": "Repeat",
		"description": "Attack {value} extra time(s) in succession.",
		"value": 1,
		"apply": func(w: Weapon) -> void: w.repeat_bonus += 1,
	},
	{
		"id": "projectile_speed",
		"title": "Projectile Speed",
		"description": "+{value}% projectile travel speed.",
		"value": 30,
		"apply": func(w: Weapon) -> void: w.projectile_speed_bonus += 0.30,
	},
	{
		"id": "projectile_speed_down",
		"title": "Slow Projectiles",
		"description": "-{value}% projectile travel speed (slow orbs linger).",
		"value": 30,
		"apply": func(w: Weapon) -> void: w.projectile_speed_bonus -= 0.30,
	},
	{
		"id": "duration_shorten",
		"title": "Shorter Duration",
		"description": "-{value}% effect duration (bombs go off sooner).",
		"value": 25,
		"apply": func(w: Weapon) -> void: w.duration_bonus -= 0.25,
	},
	{
		"id": "close_range_damage",
		"title": "Close Range",
		"description": "+{value}% damage to close enemies (first third of reach).",
		"value": 40,
		"apply": func(w: Weapon) -> void: w.close_range_damage_bonus += 0.40,
	},
	{
		"id": "far_range_damage",
		"title": "Far Range",
		"description": "+{value}% damage to far enemies (beyond two-thirds of reach).",
		"value": 40,
		"apply": func(w: Weapon) -> void: w.far_range_damage_bonus += 0.40,
	},
	{
		"id": "explosion_on_kill",
		"title": "Explosion on Kill",
		"description": "{value}% chance kills explode in an AOE.",
		"value": 25,
		"apply": func(w: Weapon) -> void: w.explosion_on_kill_chance = minf(1.0, w.explosion_on_kill_chance + 0.25),
	},
	{
		"id": "element_fire",
		"title": "Fire Damage",
		"description": "Convert damage to FIRE.",
		"value": 0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.FIRE,
	},
	{
		"id": "element_lightning",
		"title": "Lightning Damage",
		"description": "Convert damage to LIGHTNING.",
		"value": 0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.LIGHTNING,
	},
	{
		"id": "element_cold",
		"title": "Cold Damage",
		"description": "Convert damage to COLD.",
		"value": 0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.COLD,
	},
	{
		"id": "element_arcane",
		"title": "Arcane Damage",
		"description": "Convert damage to ARCANE.",
		"value": 0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.ARCANE,
	},
	{
		"id": "element_necrotic",
		"title": "Necrotic Damage",
		"description": "Convert damage to NECROTIC.",
		"value": 0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.NECROTIC,
	},
	{
		"id": "element_holy",
		"title": "Holy Damage",
		"description": "Convert damage to HOLY.",
		"value": 0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.HOLY,
	},
	{
		"id": "element_poison",
		"title": "Poison Damage",
		"description": "Convert damage to POISON.",
		"value": 0,
		"apply": func(w: Weapon) -> void: w.damage_type = DamageType.Type.POISON,
	},
]

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var weapon_list: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical/WeaponScroll/WeaponList") as VBoxContainer
@onready var stat_box: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical/StatBox") as VBoxContainer
@onready var choice_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/Choice1") as Button
@onready var choice_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/Choice2") as Button
@onready var choice_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/Choice3") as Button
@onready var back_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatBox/BackButton") as Button

var rng := RandomNumberGenerator.new()
var _current_player: Player = null
var _selected_weapon: Weapon = null
var _current_stats: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	visible = false
	_bind_buttons()


func _bind_buttons() -> void:
	if choice_1 and not choice_1.pressed.is_connected(_on_stat_pressed.bind(0)):
		choice_1.pressed.connect(_on_stat_pressed.bind(0))
	if choice_2 and not choice_2.pressed.is_connected(_on_stat_pressed.bind(1)):
		choice_2.pressed.connect(_on_stat_pressed.bind(1))
	if choice_3 and not choice_3.pressed.is_connected(_on_stat_pressed.bind(2)):
		choice_3.pressed.connect(_on_stat_pressed.bind(2))
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func open_menu() -> void:
	_current_player = get_tree().get_first_node_in_group("player") as Player
	if _current_player == null:
		return
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

	for w: Weapon in weapons:
		var btn := Button.new()
		btn.text = w.weapon_name
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_weapon_pressed.bind(w))
		weapon_list.add_child(btn)

	if title_label:
		title_label.text = "The Anvil"
	if subtitle_label:
		subtitle_label.text = "Choose a weapon to upgrade."
	weapon_list.visible = true
	if stat_box:
		stat_box.visible = false


func _on_weapon_pressed(weapon: Weapon) -> void:
	_selected_weapon = weapon
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
	if stat_box:
		stat_box.visible = true

	_update_stat_buttons()


func _roll_stats(weapon: Weapon) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for stat: Dictionary in STAT_POOL:
		if _weapon_supports(weapon, stat["id"] as String):
			pool.append(stat)

	var choices: Array[Dictionary] = []
	while choices.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		choices.append(pool[index])
		pool.remove_at(index)
	return choices


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
		"projectile_speed":
			return weapon.supports_projectile_speed()
		"projectile_speed_down":
			return weapon.supports_projectile_speed()
		"duration_shorten":
			return weapon.supports_duration()
		"close_range_damage", "far_range_damage":
			return weapon.supports_range_damage()
		"explosion_on_kill":
			return weapon.supports_explosion_on_kill()
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


func _update_stat_buttons() -> void:
	var buttons: Array[Button] = [choice_1, choice_2, choice_3]
	for i: int in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		if i >= _current_stats.size():
			button.text = "-"
			button.disabled = true
			continue
		var stat: Dictionary = _current_stats[i]
		var desc: String = (stat["description"] as String).replace("{value}", "%d" % int(stat["value"]))
		button.text = "%s\n%s" % [stat["title"], desc]
		button.disabled = false
		button.modulate = Color(0.85, 0.7, 0.95)


func _on_stat_pressed(index: int) -> void:
	if index < 0 or index >= _current_stats.size() or _selected_weapon == null:
		return
	var stat: Dictionary = _current_stats[index]
	var apply: Callable = stat["apply"] as Callable
	apply.call(_selected_weapon)
	upgrade_applied.emit(_selected_weapon, stat["id"] as String)


func _on_back_pressed() -> void:
	_selected_weapon = null
	_current_stats = []
	_show_weapon_selection()