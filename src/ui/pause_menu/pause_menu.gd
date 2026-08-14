class_name PauseMenu
extends Control

## Pause overlay: ESC pauses the game and shows Resume / Return to Main Menu.
## Instanced at runtime as a child of the HUD (CanvasLayer) so it renders above
## the 2D world and works in every arena.

const MAIN_MENU_PATH: String = "res://src/ui/main_menu/main_menu.tscn"

@onready var resume_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/ResumeButton") as Button
@onready var main_menu_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/MainMenuButton") as Button
@onready var quit_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/QuitButton") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_bind_buttons()


func _bind_buttons() -> void:
	if resume_button and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			resume()
		elif not get_tree().paused:
			pause()


func pause() -> void:
	visible = true
	get_tree().paused = true
	if resume_button:
		resume_button.grab_focus()


func resume() -> void:
	visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	resume()


func _on_main_menu_pressed() -> void:
	# Unpause and clear run state so a fresh run starts from the menu.
	get_tree().paused = false
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.has_method("end_run"):
		run_state.end_run()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
