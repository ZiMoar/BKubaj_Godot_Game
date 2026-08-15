class_name KeybindMenu
extends Control

## Keybinding screen reachable from the main menu. Lists every rebindable
## gameplay action with its current binding; clicking one arms a capture that
## waits for the next key/mouse press and writes it into the live InputMap,
## persisting via KeybindSettings. Also supports resetting all bindings to the
## project defaults.

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu/main_menu.tscn"

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var hint_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/HintLabel") as Label
@onready var bindings_box: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical/Scroll/BindingsBox") as VBoxContainer
@onready var reset_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/Footer/ResetButton") as Button
@onready var back_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/Footer/BackButton") as Button

## action -> Button showing its current binding.
var _binding_buttons: Dictionary = {}

## Action currently waiting for a new keypress, or "" when idle.
var _capturing_action: String = ""


func _ready() -> void:
	if reset_button and not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	_build_rows()
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if _capturing_action == "":
		return
	# Esc while capturing cancels the in-progress rebind.
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed:
		_cancel_capture()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Ignore modifier-only presses (Shift/Ctrl/Alt alone rebind to nothing).
		if event.physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
			return
		_assign(_capturing_action, event.physical_keycode, false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		# Left/right click are legit rebinds (primary/secondary attack).
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_assign(_capturing_action, event.button_index, true)
			get_viewport().set_input_as_handled()


func _build_rows() -> void:
	if not bindings_box:
		return
	for child: Node in bindings_box.get_children():
		bindings_box.remove_child(child)
		child.queue_free()

	for action: String in KeybindSettings.get_actions():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = KeybindSettings.get_display_name(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("font_size", 15)
		row.add_child(label)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 26)
		btn.text = ""
		btn.pressed.connect(_on_binding_pressed.bind(action))
		row.add_child(btn)

		bindings_box.add_child(row)
		_binding_buttons[action] = btn


func _refresh_all() -> void:
	for action: String in _binding_buttons:
		_refresh_one(action)


func _refresh_one(action: String) -> void:
	var btn: Button = _binding_buttons.get(action)
	if btn:
		btn.text = KeybindSettings.describe_binding(action)


func _on_binding_pressed(action: String) -> void:
	if _capturing_action != "":
		_cancel_capture()
	_capturing_action = action
	if hint_label:
		hint_label.text = "Press a key for '%s'... (Esc to cancel)" % KeybindSettings.get_display_name(action)
	_refresh_all()


func _assign(action: String, keycode: int, is_mouse: bool) -> void:
	# Reject binding an action to Escape (reserved for back/menu interactions).
	if not is_mouse and keycode == KEY_ESCAPE:
		_cancel_capture()
		return
	KeybindSettings.set_binding(action, keycode, is_mouse)
	KeybindSettings.save_current()
	_capturing_action = ""
	if hint_label:
		hint_label.text = "Click a binding, then press the new key. Esc cancels."
	_refresh_all()


func _cancel_capture() -> void:
	_capturing_action = ""
	if hint_label:
		hint_label.text = "Click a binding, then press the new key. Esc cancels."
	_refresh_all()


func _on_reset_pressed() -> void:
	_cancel_capture()
	KeybindSettings.reset_defaults()
	_refresh_all()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
