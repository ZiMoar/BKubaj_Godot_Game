class_name PauseMenu
extends Control

## Pause overlay: ESC pauses the game and shows Resume / Return to Main Menu.
## Instanced at runtime as a child of the HUD (CanvasLayer) so it renders above
## the 2D world and works in every arena.

const MAIN_MENU_PATH: String = "res://src/ui/main_menu/main_menu.tscn"

@onready var resume_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/ResumeButton") as Button
@onready var stats_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/StatsButton") as Button
@onready var main_menu_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/MainMenuButton") as Button
@onready var quit_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/QuitButton") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_bind_buttons()


func _bind_buttons() -> void:
	if resume_button and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if stats_button and not stats_button.pressed.is_connected(_on_stats_pressed):
		stats_button.pressed.connect(_on_stats_pressed)
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)


func _on_stats_pressed() -> void:
	# Hide the pause menu (keeping the game paused) and hand off to the stats
	# overlay, which is instanced as a sibling in the HUD.
	visible = false
	var stats_overlay: Node = get_node_or_null("../StatsOverlay")
	if stats_overlay and stats_overlay.has_method("open"):
		stats_overlay.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			resume()
		elif not get_tree().paused:
			pause()


func pause() -> void:
	visible = true
	PauseCoord.begin_block()
	if resume_button:
		resume_button.grab_focus()


func resume() -> void:
	visible = false
	PauseCoord.end_block()


func _on_resume_pressed() -> void:
	resume()


func _on_main_menu_pressed() -> void:
	# Clear the coordinated pause and run state so a fresh run starts from the menu.
	PauseCoord.reset()
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.has_method("end_run"):
		run_state.end_run()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_quit_pressed() -> void:
	PauseCoord.reset()
	get_tree().quit()
