class_name ArsenalMenu
extends Control

## Compendium browser. Reads Arsenal.entries() for each category and
## shows a scrollable list on the left with a detail panel on the right.
## Launched from the main menu (not in-game).

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu/main_menu.tscn"

@onready var tabs_box: HBoxContainer = get_node_or_null("Center/Panel/Vertical/Tabs") as HBoxContainer
@onready var title_label: Label = get_node_or_null("Center/Panel/Vertical/TitleLabel") as Label
@onready var list_box: VBoxContainer = get_node_or_null("Center/Panel/Vertical/Split/ListScroll/List") as VBoxContainer
@onready var detail_name: Label = get_node_or_null("Center/Panel/Vertical/Split/DetailPanel/Detail/DetailName") as Label
@onready var detail_subtitle: Label = get_node_or_null("Center/Panel/Vertical/Split/DetailPanel/Detail/DetailSubtitle") as Label
@onready var detail_desc: Label = get_node_or_null("Center/Panel/Vertical/Split/DetailPanel/Detail/DetailDesc") as Label
@onready var back_button: Button = get_node_or_null("Center/Panel/Vertical/BackButton") as Button

var _current_category: String = Arsenal.CATEGORY_WEAPONS
var _current_selection: Dictionary = {}


func _ready() -> void:
	_build_tabs()
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	_show_category(_current_category)


func _build_tabs() -> void:
	if tabs_box == null:
		return
	for child in tabs_box.get_children():
		child.queue_free()
	for cat: String in Arsenal.categories():
		var btn := Button.new()
		btn.text = Arsenal.category_title(cat)
		btn.custom_minimum_size = Vector2(110, 36)
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		tabs_box.add_child(btn)


func _on_tab_pressed(cat: String) -> void:
	_show_category(cat)


func _show_category(cat: String) -> void:
	_current_category = cat
	if title_label:
		title_label.text = "Compendium — %s" % Arsenal.category_title(cat)
	_clear_detail()
	_populate_list(Arsenal.entries(cat))


func _populate_list(entries_arr: Array[Dictionary]) -> void:
	if list_box == null:
		return
	for child in list_box.get_children():
		child.queue_free()
	if entries_arr.is_empty():
		var empty := Label.new()
		empty.text = "Nothing here yet."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		list_box.add_child(empty)
		return
	for entry: Dictionary in entries_arr:
		var btn := Button.new()
		btn.text = "%s\n%s" % [entry["name"] as String, entry.get("subtitle", "") as String]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 52)
		btn.pressed.connect(_on_entry_pressed.bind(entry))
		list_box.add_child(btn)
	# Focus the first entry so keyboard navigation starts immediately.
	if list_box.get_child_count() > 0:
		var first: Button = list_box.get_child(0) as Button
		first.grab_focus()
		if not entries_arr.is_empty():
			_on_entry_pressed(entries_arr[0])


func _on_entry_pressed(entry: Dictionary) -> void:
	_current_selection = entry
	if detail_name:
		detail_name.text = entry["name"] as String
		detail_name.add_theme_color_override("font_color", entry.get("color", Color(1, 0.84, 0.35)) as Color)
	if detail_subtitle:
		detail_subtitle.text = entry.get("subtitle", "") as String
	if detail_desc:
		detail_desc.text = entry.get("desc", "") as String


func _clear_detail() -> void:
	_current_selection = {}
	if detail_name:
		detail_name.text = "Select an entry"
		detail_name.remove_theme_color_override("font_color")
	if detail_subtitle:
		detail_subtitle.text = ""
	if detail_desc:
		detail_desc.text = ""


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
