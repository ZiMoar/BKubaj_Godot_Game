class_name MainMenu
extends Control

## Main menu / title screen. Entry point into the game.
## The layout is deliberately structured so that a class-selection section
## (a grid of class cards) can be inserted between the subtitle and the
## StartButton when classes are implemented.

const CLASS_SELECT_SCENE: String = "res://src/ui/class_select_menu/class_select_menu.tscn"
const ARSENAL_SCENE: String = "res://src/ui/arsenal_menu/arsenal_menu.tscn"
const KEYBINDS_SCENE: String = "res://src/ui/keybind_menu/keybind_menu.tscn"

@onready var start_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/StartButton") as Button
@onready var quit_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/QuitButton") as Button


func _ready() -> void:
	# Bring previously-saved player keybinds back onto the InputMap before the
	# run starts (the autoload seeds this too, but this is a safety net for any
	# scene that loads straight into gameplay).
	KeybindSettings.apply_saved()
	_build_keybinds_button()

	# Give keyboard focus to Start so Enter immediately begins a run.
	if start_button:
		start_button.grab_focus()


func _build_keybinds_button() -> void:
	# Insert a KEYBINDS button just below Arsenal. Built in code (rather than in
	# the .tscn) because the editor reverts external scene edits.
	var vertical: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical") as VBoxContainer
	if vertical == null:
		return
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = "KEYBINDS"
	btn.pressed.connect(_on_keybinds_pressed)
	# Place after the ArsenalButton if present, else before Quit.
	btn.name = "KeybindsButton"
	vertical.add_child(btn)
	var arsenal := vertical.get_node_or_null("ArsenalButton")
	if arsenal != null:
		vertical.move_child(btn, arsenal.get_index() + 1)


func _unhandled_input(event: InputEvent) -> void:
	# Allow Enter/Space to start even before focus lands on the button.
	if event.is_action_pressed("ui_accept"):
		_start_game()


func _on_arsenal_pressed() -> void:
	get_tree().change_scene_to_file(ARSENAL_SCENE)


func _on_keybinds_pressed() -> void:
	get_tree().change_scene_to_file(KEYBINDS_SCENE)


func _on_start_pressed() -> void:
	_start_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _start_game() -> void:
	# PLAY opens the class-selection screen, which then launches the arena.
	# change_scene_to_file replaces the current scene with a fresh one, which
	# naturally resets all run state (player stats, XP, gold, artefacts).
	get_tree().change_scene_to_file(CLASS_SELECT_SCENE)
