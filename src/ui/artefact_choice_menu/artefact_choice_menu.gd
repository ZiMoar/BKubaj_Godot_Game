class_name ArtefactChoiceMenu
extends Control

signal artefact_selected(artefact_id: String)

const ARTEFACTS: Script = preload("res://src/systems/artefact.gd")

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var button_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice1") as Button
@onready var button_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice2") as Button
@onready var button_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice3") as Button
@onready var reroll_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/RerollButton") as Button

var rng := RandomNumberGenerator.new()
var current_choices: Array[String] = []
var _current_player: Player = null
var _rerolls_done: int = 0
var _is_cursed: bool = false

## Artefact rerolls are the most expensive.
const REROLL_BASE_COST: int = 300


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


func open_for_player(player: Player, cursed_only: bool = false) -> void:
	if player == null:
		return
	if not player.has_method("get_artefact_count") or not player.has_method("get_artefact_slot_capacity"):
		return
	# Normal and cursed relics share the same 5-slot inventory, so always cap
	# against the combined count.
	if player.get_artefact_count() >= player.get_artefact_slot_capacity():
		return

	visible = true
	_current_player = player
	_is_cursed = cursed_only
	_rerolls_done = 0
	current_choices = _pick_choices(player)
	_update_labels()
	_update_buttons()
	_update_reroll_ui()


func close_menu() -> void:
	visible = false


# Pick up to 3 random artefacts the player does not already own. When cursed_only
# is set, restrict to cursed relics (uses the cursed slot pool).
func _pick_choices(player: Player, exclude_start: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []
	for id: String in ARTEFACTS.all_ids():
		if not player.has_artefact(id) and not id in exclude_start:
			if _is_cursed and not ARTEFACTS.is_cursed(id):
				continue
			pool.append(id)

	var choices: Array[String] = []
	while choices.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		var id: String = pool[index]
		pool.remove_at(index)
		choices.append(id)
	return choices


func _update_labels() -> void:
	if title_label:
		title_label.text = "Cursed Relic!" if _is_cursed else "Artefact Relic!"
	if subtitle_label:
		subtitle_label.text = "Strong, but at a cost." if _is_cursed else "Choose an artefact to equip."


func _update_buttons() -> void:
	var buttons: Array = [button_1, button_2, button_3]
	for i: int in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		if i >= current_choices.size():
			button.text = "-"
			button.disabled = true
			button.modulate = Color.WHITE
			continue

		var id: String = current_choices[i]
		var colour: Color = ARTEFACTS.get_display_color(id)
		button.text = "%s\n%s" % [ARTEFACTS.get_display_name(id), ARTEFACTS.get_description(id)]
		button.disabled = false
		button.modulate = colour


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
	current_choices = _pick_choices(_current_player, current_choices.duplicate())
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
	artefact_selected.emit(current_choices[index])
