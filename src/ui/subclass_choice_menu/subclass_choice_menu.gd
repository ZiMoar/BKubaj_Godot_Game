class_name SubclassChoiceMenu
extends Control

## In-run menu opened by the Altar of Ascension (room 10). Shows the 3 subclass
## (ascension) options for the player's current class. Picking one stores it in
## GameState and applies its passive to the player immediately.
##
## Uses the same blocking-ui pattern as the artefact/relic menus: it is a member
## of the "blocking_ui" group and emits `closed` when it finishes so the HUD can
## release its matching pause block (keeps the permanent-pause freeze guard
## balanced — one end_block per open).

signal closed

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var button_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice1") as Button
@onready var button_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice2") as Button
@onready var button_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice3") as Button

var _options: Array[SubclassBase] = []
var _player: Player = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("blocking_ui")
	visible = false
	_bind_buttons()


func _bind_buttons() -> void:
	if button_1 and not button_1.pressed.is_connected(_on_choice_pressed.bind(0)):
		button_1.pressed.connect(_on_choice_pressed.bind(0))
	if button_2 and not button_2.pressed.is_connected(_on_choice_pressed.bind(1)):
		button_2.pressed.connect(_on_choice_pressed.bind(1))
	if button_3 and not button_3.pressed.is_connected(_on_choice_pressed.bind(2)):
		button_3.pressed.connect(_on_choice_pressed.bind(2))


func open_for_player(player: Player) -> void:
	if player == null:
		return
	_player = player
	_options = []
	var class_id: String = _player_class_id(player)
	var state: Node = get_node_or_null("/root/GameState")
	if state and state.has_method("get_subclasses_for_class") and not class_id.is_empty():
		_options = state.get_subclasses_for_class(class_id)
	visible = true
	_update_ui()


func _player_class_id(player: Node) -> String:
	if player and player.has_method("get_class_id"):
		return player.get_class_id()
	var pid: Variant = player.get("player_class_id") if player else null
	if pid is String and not (pid as String).is_empty():
		return pid as String
	return ""


func _update_ui() -> void:
	if title_label:
		title_label.text = "Ascend"
	if subtitle_label:
		subtitle_label.text = "Choose your subclass. Its passive lasts the rest of the run."
	var buttons: Array = [button_1, button_2, button_3]
	for i: int in range(buttons.size()):
		var button: Button = buttons[i] as Button
		if button == null:
			continue
		if i >= _options.size():
			button.text = "-"
			button.disabled = true
			button.visible = false
			continue
		var sub: SubclassBase = _options[i]
		button.text = "%s\n%s" % [sub.display_name, sub.description]
		button.disabled = false
		button.visible = true


func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	var sub: SubclassBase = _options[index]
	var state: Node = get_node_or_null("/root/GameState")
	if state and state.has_method("set_selected_subclass"):
		state.set_selected_subclass(sub.class_id)
	# Apply the passive to the current player right away (static stats now;
	# dynamic behaviors hook in here too as passives are implemented). Fall back
	# to the in-game player if our stored reference went stale.
	var target: Player = _player
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Player
	if target and sub.has_method("apply"):
		sub.apply(target)
	close_menu()


func close_menu() -> void:
	visible = false
	closed.emit()
