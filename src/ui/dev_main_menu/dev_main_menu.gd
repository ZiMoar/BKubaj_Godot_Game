class_name DevMainMenu
extends Control

## DEV-ONLY main menu. Lets the developer jump straight into any newly-built room
## (Shop / Special Anvil / Relic) to test how it looks and functions. This menu is
## separate from the shipped Main Menu and is never reachable in the normal flow —
## launch it directly in the editor (or via a dev shortcut).

const SHOP_ARENA: String = "res://src/environment/dev/dev_shop_arena.tscn"
const SPECIAL_ANVIL_ARENA: String = "res://src/environment/dev/dev_special_anvil_arena.tscn"
const RELIC_ARENA: String = "res://src/environment/dev/dev_relic_arena.tscn"
const MAIN_MENU_SCENE: String = "res://src/ui/main_menu/main_menu.tscn"

const ROOMS: Array[Dictionary] = [
	{"name": "Shop Room", "path": SHOP_ARENA, "desc": "Spend gold at pedestals: +1 level, anvil, special, heal."},
	{"name": "Special Anvil Room", "path": SPECIAL_ANVIL_ARENA, "desc": "Free elemental/inverted/golden anvil in the middle."},
	{"name": "Relic Room", "path": RELIC_ARENA, "desc": "Free relic pedestal (10% cursed)."},
]

@onready var list_box: VBoxContainer = get_node_or_null("Center/Panel/Vertical/Scroll/List") as VBoxContainer
@onready var back_button: Button = get_node_or_null("Center/Panel/Vertical/BackButton") as Button


func _ready() -> void:
	KeybindSettings.apply_saved()
	_build_room_list()
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func _build_room_list() -> void:
	if list_box == null:
		return
	for child in list_box.get_children():
		child.queue_free()

	for room: Dictionary in ROOMS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(460, 56)
		button.text = "%s\n%s" % [room["name"], room["desc"]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_room_pressed.bind(room["path"]))
		list_box.add_child(button)

	if list_box.get_child_count() > 0:
		list_box.get_child(0).grab_focus()


func _on_room_pressed(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
