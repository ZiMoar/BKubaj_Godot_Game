class_name WeaponChoiceMenu
extends Control

signal weapon_selected(weapon_scene: PackedScene)

# Pool of automatic weapons the chest can offer
const AUTO_WEAPON_POOL: Array[Dictionary] = [
	{"scene": preload("res://src/entities/player/weapons/aura/aura_weapon.tscn"), "name": "Fire Aura",       "cooldown": 1.0, "desc": "Damages all enemies around you"},
	{"scene": preload("res://src/entities/player/weapons/book/book_weapon.tscn"), "name": "Orbiting Books", "cooldown": 5.0, "desc": "Books spiral outward and orbit you"},
	{"scene": preload("res://src/entities/player/weapons/dagger_fan/dagger_fan_weapon.tscn"), "name": "Dagger Fan",      "cooldown": 1.8, "desc": "A piercing ring of daggers around you"},
	{"scene": preload("res://src/entities/player/weapons/lightning/lightning_weapon.tscn"), "name": "Lightning Bolt",  "cooldown": 2.0, "desc": "Chain lightning strikes nearby enemies"},
	{"scene": preload("res://src/entities/player/weapons/frost_nova/frost_nova_weapon.tscn"), "name": "Frost Nova",     "cooldown": 3.0, "desc": "Damages and slows enemies around you"},
	{"scene": preload("res://src/entities/player/weapons/chromatic_bolt/chromatic_bolt_weapon.tscn"), "name": "Chromatic Bolt", "cooldown": 2.5, "desc": "Orb fires bolts of random damage type; slows and lingers"},
	{"scene": preload("res://src/entities/player/weapons/poison_spray/poison_spray_weapon.tscn"), "name": "Poison Spray",   "cooldown": 3.2, "desc": "Continuous poison stream that lingers over the area", "compendium_desc": "Sprays a continuous stream of poison that lingers over the area. It deals no direct damage - it only inflicts the POISON ailment, guaranteed. Because the ailment can't miss, your Ailment Chance boosts this skill's poison strength instead."},
	{"scene": preload("res://src/entities/player/weapons/radiant_barrier/radiant_barrier_weapon.tscn"), "name": "Radiant Barrier", "cooldown": 7.0, "desc": "Blocks the next hit and releases a holy wave"},
	{"scene": preload("res://src/entities/player/weapons/hungry_skull/hungry_skull_weapon.tscn"), "name": "Hungry Skull",    "cooldown": 3.5, "desc": "A homing skull that chews enemies with necrotic damage"},
	{"scene": preload("res://src/entities/player/weapons/magic_pulse/magic_pulse_weapon.tscn"), "name": "Magic Pulse",     "cooldown": 2.2, "desc": "Cone of arcane energy that pushes enemies back"},
	{"scene": preload("res://src/entities/player/weapons/explosive_charge/explosive_charge_weapon.tscn"), "name": "Explosive Charge", "cooldown": 3.0, "desc": "Drops a bomb that explodes with fire — longer fuze, bigger boom"},
]

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var button_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice1") as Button
@onready var button_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice2") as Button
@onready var button_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice3") as Button
@onready var reroll_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/RerollButton") as Button

var rng := RandomNumberGenerator.new()
var current_choices: Array[Dictionary] = []
var _rerolls_done: int = 0

## Weapon rerolls are a bit more expensive than level-up rerolls.
const REROLL_BASE_COST: int = 50


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("blocking_ui")
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


func open_menu() -> void:
	visible = true
	_rerolls_done = 0
	current_choices = _pick_choices()
	_update_labels()
	_update_buttons()
	_update_reroll_ui()


func close_menu() -> void:
	visible = false


func _get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _pick_choices(exclude_extra: Array[String] = []) -> Array[Dictionary]:
	# Filter out weapons the player already owns (no duplicates)
	var owned_paths: Array[String] = exclude_extra.duplicate()
	var player: Player = _get_player()
	var weapons_container: Node = player.get_node_or_null("Weapons") if player else null
	if weapons_container:
		for w: Node in weapons_container.get_children():
			if w is Weapon:
				owned_paths.append(w.scene_file_path)

	var pool: Array[Dictionary] = []
	for choice: Dictionary in AUTO_WEAPON_POOL:
		if not (choice["scene"] as PackedScene).resource_path in owned_paths:
			pool.append(choice)

	var choices: Array[Dictionary] = []
	while choices.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		var choice: Dictionary = pool[index]
		pool.remove_at(index)
		choices.append(choice)

	return choices


func _update_labels() -> void:
	if title_label:
		title_label.text = "Treasure Chest!"
	if subtitle_label:
		subtitle_label.text = "Choose a new automatic weapon."


func _update_buttons() -> void:
	var buttons: Array = [button_1, button_2, button_3]
	for i: int in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		if i >= current_choices.size():
			button.text = "-"
			button.disabled = true
			continue

		var choice: Dictionary = current_choices[i]
		button.text = "%s\n%s\nCooldown: %.1fs" % [choice["name"], choice["desc"], choice["cooldown"]]
		button.disabled = false
		button.modulate = Color(1.0, 0.85, 0.3)  # Gold tint for treasure


func get_current_reroll_cost() -> int:
	# Free rerolls on the test map (detected via TestFacilities presence).
	if get_tree().get_first_node_in_group("test_facilities") != null:
		return 0
	return REROLL_BASE_COST * (1 << _rerolls_done)


func _on_reroll_pressed() -> void:
	var player: Player = _get_player()
	if player == null:
		return
	var cost: int = get_current_reroll_cost()
	if not player.can_afford(cost):
		_update_reroll_ui()
		return
	if not player.spend_gold(cost):
		_update_reroll_ui()
		return

	_rerolls_done += 1
	var exclude: Array[String] = []
	for c: Dictionary in current_choices:
		var sc: PackedScene = c["scene"] as PackedScene
		exclude.append(sc.resource_path)
	current_choices = _pick_choices(exclude)
	_update_buttons()
	_update_reroll_ui()


func _update_reroll_ui() -> void:
	if reroll_button == null:
		return
	var player: Player = _get_player()
	var cost: int = get_current_reroll_cost()
	var affordable: bool = player != null and player.can_afford(cost)
	reroll_button.text = "Reroll (%dg)" % cost
	reroll_button.disabled = not affordable


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return

	var scene: PackedScene = current_choices[index]["scene"] as PackedScene
	weapon_selected.emit(scene)
