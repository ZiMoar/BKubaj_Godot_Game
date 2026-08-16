class_name RunSummary
extends Control

## Defeat / end-of-run screen. Reads the run stats captured in GameState
## (kills, elapsed time, difficulty reached, gold) and shows them, then lets
## the player either retry the run with the same choices (same map + character)
## or return to the main menu.

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu/main_menu.tscn"

@onready var title_label: Label = get_node_or_null("Center/Panel/Vertical/TitleLabel") as Label
@onready var stats_box: VBoxContainer = get_node_or_null("Center/Panel/Vertical/Stats") as VBoxContainer
@onready var retry_button: Button = get_node_or_null("Center/Panel/Vertical/RetryButton") as Button
@onready var menu_button: Button = get_node_or_null("Center/Panel/Vertical/MenuButton") as Button


func _ready() -> void:
	_populate()
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
		retry_button.grab_focus()
	if menu_button and not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)


func _populate() -> void:
	if stats_box == null:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	var elapsed: int = int(gs.get("run_elapsed_seconds")) if gs else 0
	var kills: int = int(gs.get("run_kills")) if gs else 0
	var diff: float = float(gs.get("run_difficulty_at_end")) if gs else 0.0
	var gold: int = int(gs.get("run_gold_at_end")) if gs else 0
	var stage_num: int = int(gs.get("stage")) if gs else 1

	_add_stat("Time survived", _format_time(elapsed))
	_add_stat("Stages cleared", "%d" % maxi(0, stage_num - 1))
	_add_stat("Enemies slain", "%d" % kills)
	_add_stat("Difficulty reached", "%.1f" % diff)
	_add_stat("Gold collected", "%d" % gold)


func _add_stat(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_l := Label.new()
	name_l.text = label_text
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_l.add_theme_font_size_override("font_size", 15)
	var val_l := Label.new()
	val_l.text = value_text
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_l.add_theme_color_override("font_color", Color(1, 0.84, 0.35))
	val_l.add_theme_font_size_override("font_size", 15)
	row.add_child(name_l)
	row.add_child(val_l)
	stats_box.add_child(row)


func _format_time(total_seconds: int) -> String:
	var m: int = int(total_seconds / 60.0)
	var s: int = total_seconds % 60
	return "%d:%02d" % [m, s]


## Retry: restart a fresh run on the same map, keeping the same character.
## GameState.retry_run() preserves the selected class/map and returns the path
## to the first combat arena to load into.
func _on_retry_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("retry_run"):
		var path: String = gs.retry_run()
		if not path.is_empty():
			get_tree().change_scene_to_file(path)
			return
	# Fallback: if GameState isn't available, just restart the run directly.
	get_tree().change_scene_to_file("res://src/environment/catacombs_arena.tscn")


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
