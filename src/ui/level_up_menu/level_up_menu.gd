class_name LevelUpMenu
extends Control

signal upgrade_selected(upgrade_id: String, rarity: int)

enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4,
}

const RARITY_NAMES: Dictionary = {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary",
}

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.75, 0.75, 0.75),
	Rarity.UNCOMMON: Color(0.25, 0.88, 0.35),
	Rarity.RARE: Color(0.30, 0.50, 1.0),
	Rarity.EPIC: Color(0.70, 0.30, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.55, 0.05),
}

const RARITY_FONT_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.55, 0.55, 0.55),
	Rarity.UNCOMMON: Color(0.18, 0.72, 0.25),
	Rarity.RARE: Color(0.22, 0.40, 0.90),
	Rarity.EPIC: Color(0.60, 0.22, 0.90),
	Rarity.LEGENDARY: Color(0.95, 0.50, 0.05),
}

# Base rarity weights: 60/25/10/4/1 (sum = 100)
const BASE_RARITY_WEIGHTS: Array[float] = [60.0, 25.0, 10.0, 4.0, 1.0]

# Luck redistribution proportions when shifting weight from COMMON
const LUCK_REDISTRIBUTION: Array[float] = [0.0, 0.35, 0.30, 0.20, 0.15]

const UPGRADE_POOL: Array[Dictionary] = [
	# --- Offense ---
	{"id": "might_flat",           "title": "Power",         "description": "+{value} damage.",                     "min_rarity": Rarity.COMMON,    "base_value": 1.0,   "value_scaling": 0.5},
	{"id": "might_percent",        "title": "Might %",       "description": "+{value}% total damage.",               "min_rarity": Rarity.COMMON,    "base_value": 0.10,  "value_scaling": 0.05},
	{"id": "attack_speed",         "title": "Attack Speed",  "description": "+{value} attack speed.",               "min_rarity": Rarity.COMMON,    "base_value": 20.0,  "value_scaling": 10.0},
	{"id": "crit_chance",          "title": "Crit Chance",   "description": "+{value}% crit chance.",                "min_rarity": Rarity.UNCOMMON,  "base_value": 0.05,  "value_scaling": 0.025},
	{"id": "crit_damage",          "title": "Crit Damage",   "description": "+{value}x crit multiplier.",             "min_rarity": Rarity.UNCOMMON,  "base_value": 0.25,  "value_scaling": 0.15},
	{"id": "ailment_chance",       "title": "Ailment Chance","description": "+{value}% chance to inflict the ailment matching your damage type.", "min_rarity": Rarity.UNCOMMON, "base_value": 0.10, "value_scaling": 0.05},
	# --- Survival ---
	{"id": "max_health",           "title": "Max Health",    "description": "+{value} max HP.",                      "min_rarity": Rarity.COMMON,    "base_value": 10.0,  "value_scaling": 5.0},
	{"id": "armor",                "title": "Armor",         "description": "+{value} armor.",                           "min_rarity": Rarity.UNCOMMON,  "base_value": 20.0,  "value_scaling": 12.0},
	{"id": "evasion",              "title": "Evasion",       "description": "+{value}% dodge chance.",               "min_rarity": Rarity.RARE,      "base_value": 0.02,  "value_scaling": 0.01},
	{"id": "hp_regen",             "title": "HP Regen",      "description": "+{value} HP/sec.",                      "min_rarity": Rarity.COMMON,    "base_value": 0.25,  "value_scaling": 0.15},
	{"id": "lifesteal",            "title": "Life Steal",    "description": "+{value} heal on hit.",                 "min_rarity": Rarity.UNCOMMON,  "base_value": 1.0,   "value_scaling": 0.5},
	{"id": "thorns",               "title": "Thorns",        "description": "+{value} reflected damage.",            "min_rarity": Rarity.COMMON,    "base_value": 5.0,   "value_scaling": 3.0},
	{"id": "revive",               "title": "Revive",        "description": "+{value} revive charge(s).",            "min_rarity": Rarity.EPIC,      "base_value": 1.0,   "value_scaling": 1.0},
	# --- Utility ---
	{"id": "move_speed_percent",   "title": "Move Speed %",  "description": "+{value}% walk speed.",                 "min_rarity": Rarity.COMMON,    "base_value": 0.05,  "value_scaling": 0.03},
	{"id": "magnet",               "title": "Magnet",        "description": "+{value} pickup range.",                "min_rarity": Rarity.UNCOMMON,  "base_value": 25.0,  "value_scaling": 15.0},
	# --- Progression ---
	{"id": "growth",               "title": "Growth",        "description": "+{value}% XP gained.",                  "min_rarity": Rarity.UNCOMMON,  "base_value": 0.20,  "value_scaling": 0.10},
	{"id": "greed",                "title": "Greed",         "description": "+{value}% gold gained.",                 "min_rarity": Rarity.UNCOMMON,  "base_value": 0.20,  "value_scaling": 0.10},
	{"id": "luck",                 "title": "Luck",          "description": "+{value} luck, improving rarity rolls.",  "min_rarity": Rarity.UNCOMMON,  "base_value": 5.0,   "value_scaling": 3.0},
	# --- Debug ---
	{"id": "difficulty",           "title": "Difficulty",    "description": "+{value} difficulty.",                  "min_rarity": Rarity.RARE,      "base_value": 1.0,   "value_scaling": 0.5},
]

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var button_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice1") as Button
@onready var button_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice2") as Button
@onready var button_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice3") as Button
@onready var reroll_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/RerollButton") as Button

var rng := RandomNumberGenerator.new()
var current_choices: Array[Dictionary] = []
var _current_player: Player = null
var _rerolls_done: int = 0

## Reroll costs. Level-up rerolls are cheap but double each reroll in a menu.
const REROLL_BASE_COST: int = 10


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	visible = false
	_bind_buttons()


func _bind_buttons() -> void:
	if button_1 and not button_1.pressed.is_connected(_on_button_pressed.bind(0)):
		button_1.pressed.connect(_on_button_pressed.bind(0))
	if button_2 and not button_2.pressed.is_connected(_on_button_pressed.bind(1)):
		button_2.pressed.connect(_on_button_pressed.bind(1))
	if button_3 and not button_3.pressed.is_connected(_on_button_pressed.bind(2)):
		button_3.pressed.connect(_on_button_pressed.bind(2))
	if reroll_button and not reroll_button.pressed.is_connected(_on_reroll_pressed):
		reroll_button.pressed.connect(_on_reroll_pressed)


func open_for_player(player: Player, level_number: int) -> void:
	visible = true
	_current_player = player
	_rerolls_done = 0
	current_choices = _pick_choices(player.luck)
	_update_labels(level_number)
	_update_buttons()
	_update_reroll_ui()


func close_menu() -> void:
	visible = false


# --- Public helpers ---

static func get_upgrade_def(upgrade_id: String) -> Dictionary:
	for upgrade: Dictionary in UPGRADE_POOL:
		if upgrade["id"] == upgrade_id:
			return upgrade
	return {}


static func get_effective_value(upgrade_id: String, rarity: int) -> float:
	var def: Dictionary = get_upgrade_def(upgrade_id)
	if def.is_empty():
		return 0.0
	var min_rarity: int = def.get("min_rarity", 0) as int
	var base_value: float = def.get("base_value", 0.0) as float
	var value_scaling: float = def.get("value_scaling", 0.0) as float
	var tiers_above: int = max(0, rarity - min_rarity)
	return base_value + float(tiers_above) * value_scaling


static func get_rarity_name(rarity: int) -> String:
	return RARITY_NAMES.get(rarity, "Unknown") as String


static func get_rarity_color(rarity: int) -> Color:
	return RARITY_COLORS.get(rarity, Color.GRAY) as Color


# --- Rarity rolling ---

static func _get_adjusted_weights(luck: float) -> Array[float]:
	var shift: float = luck * 2.0
	var weights: Array[float] = []
	weights.resize(BASE_RARITY_WEIGHTS.size())
	weights[Rarity.COMMON] = maxf(1.0, BASE_RARITY_WEIGHTS[Rarity.COMMON] - shift)
	for i: int in range(1, BASE_RARITY_WEIGHTS.size()):
		weights[i] = BASE_RARITY_WEIGHTS[i] + shift * LUCK_REDISTRIBUTION[i]
	return weights


func _roll_rarity(luck: float) -> int:
	var weights: Array[float] = _get_adjusted_weights(luck)
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = rng.randf_range(0.0, total)
	var cumulative: float = 0.0
	for rarity: int in range(weights.size()):
		cumulative += weights[rarity]
		if roll <= cumulative:
			return rarity
	return Rarity.LEGENDARY


# --- Choice picking ---

func _pick_choices(luck: float, exclude_start: Array[String] = []) -> Array[Dictionary]:
	var used_ids: Array[String] = exclude_start.duplicate()
	var choices: Array[Dictionary] = []

	while choices.size() < 3:
		var rolled_rarity: int = _roll_rarity(luck)
		var eligible: Array[Dictionary] = _get_eligible_upgrades(rolled_rarity, used_ids)

		if eligible.is_empty():
			# Fallback: expand to lower rarities
			for fallback_rarity: int in range(rolled_rarity - 1, Rarity.COMMON - 1, -1):
				eligible = _get_eligible_upgrades(fallback_rarity, used_ids)
				if not eligible.is_empty():
					break

		if eligible.is_empty():
			break

		var pick: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)].duplicate()
		var min_r: int = pick.get("min_rarity", 0) as int
		pick["rolled_rarity"] = max(rolled_rarity, min_r)
		choices.append(pick)
		used_ids.append(pick["id"] as String)

	return choices


func _get_eligible_upgrades(rarity: int, exclude_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade: Dictionary in UPGRADE_POOL:
		if (upgrade["id"] as String) in exclude_ids:
			continue
		if (upgrade["min_rarity"] as int) <= rarity:
			result.append(upgrade)
	return result


# --- UI ---

func _update_labels(level_number: int) -> void:
	if title_label:
		title_label.text = "Level Up"
	if subtitle_label:
		subtitle_label.text = "Choose 1 of 3 upgrades for level %d." % level_number


func _update_buttons() -> void:
	var buttons: Array = [button_1, button_2, button_3]
	for i: int in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		if i >= current_choices.size():
			button.text = "-"
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5, 0.5)
			continue

		var choice: Dictionary = current_choices[i]
		var rarity: int = choice.get("rolled_rarity", Rarity.COMMON) as int
		var rarity_name: String = get_rarity_name(rarity)
		var rarity_color: Color = get_rarity_color(rarity)
		var font_color: Color = RARITY_FONT_COLORS.get(rarity, Color.WHITE) as Color
		var effective_value: float = get_effective_value(choice["id"] as String, rarity)

		# Format the description, replacing {value} with the actual scaled value
		var desc_template: String = choice.get("description", "") as String
		var display_value: String
		if choice["id"] in ["might_percent", "crit_chance", "ailment_chance", "evasion", "move_speed_percent", "growth", "greed"]:
			display_value = "%d%%" % int(round(effective_value * 100.0))
		elif effective_value < 1.0 and effective_value > 0.0:
			display_value = "%.2f" % effective_value
		else:
			display_value = "%.1f" % effective_value
			if display_value.ends_with(".0"):
				display_value = display_value.trim_suffix(".0")

		var description: String = desc_template.replace("{value}", display_value)

		button.text = "[%s]\n%s\n%s" % [rarity_name, choice["title"], description]
		button.modulate = rarity_color
		button.disabled = false
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", font_color.lightened(0.3))


func get_current_reroll_cost() -> int:
	return REROLL_BASE_COST * (1 << _rerolls_done)


func _on_reroll_pressed() -> void:
	if _current_player == null:
		return
	var cost: int = get_current_reroll_cost()
	if not _current_player.can_afford(cost):
		_update_reroll_ui()
		return
	if not _current_player.spend_gold(cost):
		_update_reroll_ui()
		return

	_rerolls_done += 1
	var exclude: Array[String] = []
	for c: Dictionary in current_choices:
		exclude.append(c["id"] as String)
	current_choices = _pick_choices(_current_player.luck, exclude)
	_update_buttons()
	_update_reroll_ui()


func _update_reroll_ui() -> void:
	if reroll_button == null:
		return
	var cost: int = get_current_reroll_cost()
	var affordable: bool = _current_player != null and _current_player.can_afford(cost)
	reroll_button.text = "Reroll (%dg)" % cost
	reroll_button.disabled = not affordable


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return

	var choice: Dictionary = current_choices[index]
	var rarity: int = choice.get("rolled_rarity", Rarity.COMMON) as int
	upgrade_selected.emit(str(choice["id"]), rarity)
