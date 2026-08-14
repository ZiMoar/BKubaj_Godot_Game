class_name MainMenu
extends Control

## Main menu / title screen. Entry point into the game.
## The layout is deliberately structured so that a class-selection section
## (a grid of class cards) can be inserted between the subtitle and the
## StartButton when classes are implemented.

const CLASS_SELECT_SCENE: String = "res://src/ui/class_select_menu/class_select_menu.tscn"
const ARSENAL_SCENE: String = "res://src/ui/arsenal_menu/arsenal_menu.tscn"

@onready var start_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/StartButton") as Button
@onready var quit_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/QuitButton") as Button


func _ready() -> void:
	# Give keyboard focus to Start so Enter immediately begins a run.
	if start_button:
		start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Allow Enter/Space to start even before focus lands on the button.
	if event.is_action_pressed("ui_accept"):
		_start_game()


func _on_arsenal_pressed() -> void:
	get_tree().change_scene_to_file(ARSENAL_SCENE)


func _on_start_pressed() -> void:
	_start_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _start_game() -> void:
	# PLAY opens the class-selection screen, which then launches the arena.
	# change_scene_to_file replaces the current scene with a fresh one, which
	# naturally resets all run state (player stats, XP, gold, artefacts).
	get_tree().change_scene_to_file(CLASS_SELECT_SCENE)
