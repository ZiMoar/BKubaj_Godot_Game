class_name ClassSelectMenu
extends Control

## Class-selection screen. Builds one button per class in the GameState roster,
## so extra classes added later appear here automatically. Picking a class
## stores it in GameState and starts a run with that class's weapons.

const ARENA_SCENE: String = "res://src/environment/test_arena.tscn"
const MAIN_MENU_SCENE: String = "res://src/ui/main_menu.tscn"

@onready var title_label: Label = get_node_or_null("Center/Panel/Vertical/TitleLabel") as Label
@onready var list_box: VBoxContainer = get_node_or_null("Center/Panel/Vertical/Scroll/List") as VBoxContainer
@onready var back_button: Button = get_node_or_null("Center/Panel/Vertical/BackButton") as Button


func _ready() -> void:
	if title_label:
		title_label.text = "Choose Your Class"
	_build_class_list()
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func _build_class_list() -> void:
	if list_box == null:
		return
	# Clear any pre-existing children (e.g. in the editor preview).
	for child in list_box.get_children():
		child.queue_free()

	var state: Node = get_node_or_null("/root/GameState")
	if state == null:
		return
	for cls: Dictionary in state.get_class_list():
		var button := Button.new()
		button.custom_minimum_size = Vector2(440, 58)
		button.text = "%s\n%s" % [cls["name"], cls["desc"]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_class_pressed.bind(str(cls["id"])))
		list_box.add_child(button)

	# Focus the first class so Enter / gamepad can start immediately.
	if list_box.get_child_count() > 0:
		list_box.get_child(0).grab_focus()


func _on_class_pressed(class_id: String) -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state and state.has_method("set_selected_class"):
		state.set_selected_class(class_id)
	get_tree().change_scene_to_file(ARENA_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
