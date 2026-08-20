class_name ArtefactChoiceMenu
extends Control

signal artefact_selected(artefact_id: String)
## Emitted whenever the menu fully closes (after a pick, replace, sell, or back
## out). The HUD uses it to release its pause block — one close per open.
signal closed

const ARTEFACTS: Script = preload("res://src/systems/artefact.gd")

enum Mode { CHOOSE, PROMPT, SACRIFICE }

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var button_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice1") as Button
@onready var button_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice2") as Button
@onready var button_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice3") as Button
@onready var reroll_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/RerollButton") as Button
@onready var sacrifice_container: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical/SacrificeContainer") as VBoxContainer

var rng := RandomNumberGenerator.new()
var current_choices: Array[String] = []
var _current_player: Player = null
var _rerolls_done: int = 0
var _is_cursed: bool = false

# Overflow (slots full) state machine.
var _mode: int = Mode.CHOOSE
var _is_replacing: bool = false
var _pending_new_relic: String = ""
var _sell_value: int = 0

## Artefact rerolls are the most expensive.
const REROLL_BASE_COST: int = 300
## Flat gold paid for selling an over-cap relic instead of equipping it.
const RELIC_SELL_VALUE: int = 400


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


func open_for_player(player: Player, cursed_only: bool = false) -> void:
	if player == null:
		return
	if not player.has_method("get_artefact_count") or not player.has_method("get_artefact_slot_capacity"):
		return

	_current_player = player
	_is_cursed = cursed_only
	_rerolls_done = 0
	_is_replacing = false
	_pending_new_relic = ""

	visible = true
	if player.get_artefact_count() >= player.get_artefact_slot_capacity():
		# Slots full -> ask whether to replace an equipped relic or sell this one.
		_mode = Mode.PROMPT
		_sell_value = RELIC_SELL_VALUE
		_update_prompt_ui()
	else:
		_mode = Mode.CHOOSE
		_sell_value = 0
		current_choices = _pick_choices(player)
		_update_choose_ui()


func close_menu() -> void:
	visible = false
	_clear_sacrifice()
	closed.emit()


# ---- Mode rendering ----

func _update_choose_ui() -> void:
	if title_label:
		title_label.text = "Cursed Relic!" if _is_cursed else "Artefact Relic!"
	if subtitle_label:
		if _is_replacing:
			subtitle_label.text = "Choose a new relic to take."
		else:
			subtitle_label.text = "Strong, but at a cost." if _is_cursed else "Choose an artefact to equip."
	_clear_sacrifice()
	if sacrifice_container:
		sacrifice_container.visible = false
	if reroll_button:
		reroll_button.visible = true
	_set_button_row_visible(true)
	_update_buttons()
	_update_reroll_ui()


func _update_prompt_ui() -> void:
	if title_label:
		title_label.text = "Relic slots are full!"
	if subtitle_label:
		subtitle_label.text = "Replace an equipped relic, or sell this one for gold."
	_clear_sacrifice()
	if sacrifice_container:
		sacrifice_container.visible = false
	if reroll_button:
		reroll_button.visible = false
	if button_1:
		button_1.text = "Replace a relic"
		button_1.disabled = false
		button_1.modulate = Color.WHITE
		button_1.visible = true
	if button_2:
		button_2.text = "Sell for gold (%dg)" % _sell_value
		button_2.disabled = false
		button_2.modulate = Color.WHITE
		button_2.visible = true
	if button_3:
		button_3.text = "-"
		button_3.visible = false


func _update_sacrifice_ui() -> void:
	if _current_player == null:
		close_menu()
		return
	if title_label:
		title_label.text = "Sacrifice a relic"
	if subtitle_label:
		subtitle_label.text = "Pick one of your relics to give up for %s." % ARTEFACTS.get_display_name(_pending_new_relic)
	_set_button_row_visible(false)
	if reroll_button:
		reroll_button.visible = false
	if sacrifice_container == null:
		close_menu()
		return
	sacrifice_container.visible = true
	_clear_sacrifice()
	for i in range(_current_player.get_artefact_count()):
		var id: String = _current_player.get_artefact_at_slot(i)
		if id.is_empty():
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 46)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var colour: Color = ARTEFACTS.get_display_color(id)
		b.text = "%s\n%s" % [ARTEFACTS.get_display_name(id), ARTEFACTS.get_description(id)]
		b.modulate = colour
		b.pressed.connect(_on_sacrifice_pressed.bind(id))
		sacrifice_container.add_child(b)
	# Back returns to the Replace/Sell prompt so the player isn't locked in.
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 34)
	back.pressed.connect(_on_sacrifice_back_pressed)
	sacrifice_container.add_child(back)


func _clear_sacrifice() -> void:
	if sacrifice_container == null:
		return
	for child in sacrifice_container.get_children():
		if is_instance_valid(child):
			child.queue_free()


func _set_button_row_visible(vis: bool) -> void:
	for b: Button in [button_1, button_2, button_3]:
		if b:
			b.visible = vis


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
	if _mode == Mode.PROMPT:
		_on_prompt_action(index)
		return
	if _mode != Mode.CHOOSE:
		return
	if index < 0 or index >= current_choices.size():
		return
	if _is_replacing:
		# Picked the NEW relic; now choose which equipped relic to sacrifice.
		_pending_new_relic = current_choices[index]
		_mode = Mode.SACRIFICE
		_update_sacrifice_ui()
		return
	_apply_relic(current_choices[index])


func _on_prompt_action(index: int) -> void:
	match index:
		0:  # Replace a relic
			_is_replacing = true
			_mode = Mode.CHOOSE
			current_choices = _pick_choices(_current_player)
			if current_choices.is_empty():
				# Owns every relic in this pool — nothing to take. Fall back to the
				# prompt so the player can sell instead of being soft-locked.
				_is_replacing = false
				_mode = Mode.PROMPT
				_update_prompt_ui()
				return
			_update_choose_ui()
		1:  # Sell for gold
			if _current_player:
				_current_player.add_gold(_sell_value)
			close_menu()
		_:
			close_menu()


func _apply_relic(id: String) -> void:
	# Apply on the NEXT idle frame so an error inside add_artefact (or the
	# artefacts_changed HUD handler it fires) can never abort before the menu
	# closes and the game unpauses (the permanent-pause freeze guard).
	if _current_player and _current_player.has_method("add_artefact"):
		_current_player.call_deferred("add_artefact", id)
	close_menu()


func _on_sacrifice_pressed(sacrificed_id: String) -> void:
	if _current_player == null:
		return
	_current_player.remove_artefact(sacrificed_id)
	# Add the replacement on the next frame (same freeze-safety as _apply_relic).
	if _current_player.has_method("add_artefact"):
		_current_player.call_deferred("add_artefact", _pending_new_relic)
	close_menu()


func _on_sacrifice_back_pressed() -> void:
	_is_replacing = false
	_pending_new_relic = ""
	_mode = Mode.PROMPT
	_update_prompt_ui()
