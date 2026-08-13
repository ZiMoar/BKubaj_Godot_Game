class_name MapChoiceMenu
extends Control

## Map-selection screen. Builds one button per map in the GameState roster, so
## extra maps added later appear here automatically. Picking a map stores it in
## GameState and starts a run in that map's arena scene.
##
## Deliberately simple for now — a straight list of map buttons. Later this will
## be reworked into a graphical dungeon map (thumbnails / a board showing the
## dungeons), but the roster-driven menu structure stays the same.

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu/main_menu.tscn"

@onready var title_label: Label = get_node_or_null("Center/Panel/Vertical/TitleLabel") as Label
@onready var list_box: VBoxContainer = get_node_or_null("Center/Panel/Vertical/Scroll/List") as VBoxContainer
@onready var back_button: Button = get_node_or_null("Center/Panel/Vertical/BackButton") as Button


func _ready() -> void:
	if title_label:
		title_label.text = "Choose Your Map"
	_build_map_list()
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func _build_map_list() -> void:
	if list_box == null:
		return
	# Clear any pre-existing children (e.g. in the editor preview).
	for child in list_box.get_children():
		child.queue_free()

	var state: Node = get_node_or_null("/root/GameState")
	if state == null:
		return
	for map: MapBase in state.get_map_list():
		var button := Button.new()
		button.custom_minimum_size = Vector2(440, 58)
		button.text = "%s\n%s" % [map.display_name, map.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_map_pressed.bind(map.map_id))
		list_box.add_child(button)

	# Focus the first map so Enter / gamepad can start immediately.
	if list_box.get_child_count() > 0:
		list_box.get_child(0).grab_focus()


func _on_map_pressed(map_id: String) -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state and state.has_method("set_selected_map"):
		state.set_selected_map(map_id)
	var selected: MapBase = state.get_selected_map() if state else null
	if selected == null or selected.arena_scene == null:
		return
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.has_method("begin_run"):
		run_state.begin_run(selected.arena_scene.resource_path)
	get_tree().change_scene_to_file(selected.arena_scene.resource_path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)