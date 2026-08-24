extends Node

var _frames: int = 0
var _menu: Control

func _ready() -> void:
	var ps: PackedScene = load("res://src/ui/coop_menu/coop_menu.tscn")
	_menu = ps.instantiate() as Control
	add_child(_menu)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 3:
		var scroll: ScrollContainer = _menu.get_node("Center/Panel/Scroll") as ScrollContainer
		var panel: Control = _menu.get_node("Center/Panel") as Control
		var v: VBoxContainer = _menu.get_node("Center/Panel/Scroll/Vertical") as VBoxContainer
		var vbar: ScrollBar = scroll.get_v_scroll_bar()
		print("PROBE panel rect=", panel.get_global_rect())
		print("PROBE scroll rect=", scroll.get_global_rect())
		print("PROBE vbox size=", v.size, " min=", v.get_combined_minimum_size())
		print("PROBE vbar max_value=", vbar.max_value, " visible=", vbar.visible)
		print("PROBE vscrollbar_visible=", scroll.is_v_scrollbar_visible(), " h=", scroll.is_h_scrollbar_visible())
		scroll.scroll_vertical = 99999
