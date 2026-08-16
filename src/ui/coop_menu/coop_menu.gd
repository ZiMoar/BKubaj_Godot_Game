class_name CoopMenu
extends Control

## Co-op setup screen: pick your class, then either HOST a listen server or
## JOIN a friend's host by IP. Built in code (like the keybinds button) so the
## UI matches the rest of the game without fragile editor-scene edits.

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu/main_menu.tscn"

@onready var vertical: VBoxContainer = get_node_or_null("Center/Panel/Scroll/Vertical") as VBoxContainer

var _selected_class: String = ""
var _hosting: bool = false
var _joining: bool = false

# UI handles built in code.
var _class_list: VBoxContainer
var _host_button: Button
var _join_button: Button
var _ip_edit: LineEdit
var _start_run_button: Button
var _status_label: Label


func _ready() -> void:
	if vertical == null:
		return
	var net: Node = get_node_or_null("/root/Net")
	if net != null and net.active():
		net.leave()
	_build_ui()
	_connect_net_signals()


func _build_ui() -> void:
	var title := _make_label("CO-OP", 30, Color(1, 0.84, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical.add_child(title)
	var sub := _make_label("Host a game, or join a friend over your network.", 13, Color(0.7, 0.7, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical.add_child(sub)

	vertical.add_child(_make_label("1.  Choose your class", 15, Color(0.9, 0.9, 0.95)))
	_class_list = VBoxContainer.new()
	_class_list.add_theme_constant_override("separation", 6)
	_build_class_buttons()
	vertical.add_child(_class_list)

	vertical.add_child(_make_label("2.  Host or Join", 15, Color(0.9, 0.9, 0.95)))
	_host_button = _make_button("HOST GAME")
	_host_button.pressed.connect(_on_host_pressed)
	vertical.add_child(_host_button)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Host IP (e.g. 192.168.1.10)"
	_ip_edit.custom_minimum_size = Vector2(0, 42)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_button = _make_button("JOIN GAME")
	_join_button.custom_minimum_size = Vector2(160, 0)
	_join_button.pressed.connect(_on_join_pressed)
	join_row.add_child(_ip_edit)
	join_row.add_child(_join_button)
	vertical.add_child(join_row)

	_start_run_button = _make_button("START RUN")
	_start_run_button.visible = false
	_start_run_button.pressed.connect(_start_run_pressed)
	vertical.add_child(_start_run_button)

	_status_label = _make_label("Pick a class to get started.", 13, Color(0.7, 0.7, 0.78))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical.add_child(_status_label)

	vertical.add_child(_make_spacer(6))
	var back := _make_button("BACK")
	back.pressed.connect(_on_back_pressed)
	vertical.add_child(back)

	# Focus the first class so Enter / gamepad can jump in.
	if _class_list.get_child_count() > 0:
		_class_list.get_child(0).grab_focus()


func _build_class_buttons() -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_class_list"):
		return
	for cls: ClassBase in state.get_class_list():
		var btn := _make_button("%s\n%s" % [cls.display_name, cls.description], 60)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.pressed.connect(_on_class_pressed.bind(cls.class_id))
		_class_list.add_child(btn)


func _connect_net_signals() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net == null:
		return
	if not net.connected_to_host.is_connected(_on_connected_to_host):
		net.connected_to_host.connect(_on_connected_to_host)
	if not net.connection_failed_to_host.is_connected(_on_connection_failed):
		net.connection_failed_to_host.connect(_on_connection_failed)
	if not net.peer_connected.is_connected(_on_peer_count_changed):
		net.peer_connected.connect(_on_peer_count_changed)
	if not net.peer_left.is_connected(_on_peer_count_changed):
		net.peer_left.connect(_on_peer_count_changed)


func _on_class_pressed(class_id: String) -> void:
	_selected_class = class_id
	var state: Node = get_node_or_null("/root/GameState")
	var name_text: String = class_id
	if state and state.has_method("get_class_by_id"):
		var cls: ClassBase = state.get_class_by_id(class_id)
		if cls:
			name_text = cls.display_name
	_set_status("Class selected: %s. Now host or join." % name_text, false)


func _on_host_pressed() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net == null:
		return
	if _selected_class.is_empty():
		_set_status("Pick a class first.", true)
		return
	var err: int = net.create_host(_selected_class)
	if err != OK:
		_set_status("Could not start host (error %d)." % err, true)
		return
	_hosting = true
	_joining = false
	_set_ui_locked(true)
	_start_run_button.visible = true
	_update_host_count()


func _start_run_pressed() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("host_start_run"):
		net.host_start_run()


func _on_join_pressed() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net == null:
		return
	if _selected_class.is_empty():
		_set_status("Pick a class first.", true)
		return
	var ip: String = _ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err: int = net.join_game(ip, _selected_class)
	if err != OK:
		_set_status("Could not connect (error %d)." % err, true)
		return
	_joining = true
	_hosting = false
	_set_ui_locked(true)
	_set_status("Connecting to %s..." % ip, false)


func _on_connected_to_host() -> void:
	_set_status("Connected! Waiting for the host to start the run...", false)


func _on_connection_failed() -> void:
	_joining = false
	_set_ui_locked(false)
	_set_status("Connection failed. Check the host IP and try again.", true)


func _on_peer_count_changed(_id: int = -1) -> void:
	if _hosting:
		_update_host_count()


func _update_host_count() -> void:
	var net: Node = get_node_or_null("/root/Net")
	var count: int = net.peer_classes.size() if net else 1
	_set_status("Hosting on port %d. Players ready: %d. Press START RUN when set." % [net.DEFAULT_PORT if net else 0, count], false)


func _set_ui_locked(locked: bool) -> void:
	for child: Control in _class_list.get_children():
		child.disabled = locked
	_host_button.disabled = locked
	_join_button.disabled = locked
	_ip_edit.editable = not locked


func _set_status(text: String, is_error: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.5) if is_error else Color(0.7, 0.7, 0.78))


func _on_back_pressed() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net:
		net.leave()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# --- UI helpers ---

func _make_button(text: String, min_h: int = 40) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.16, 0.21, 0.95)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.5, 0.45, 0.3, 1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.23, 0.12, 1)
	hover.border_color = Color(0.95, 0.8, 0.4, 1)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.4, 0.32, 0.14, 1)
	pressed.border_color = Color(1, 0.85, 0.45, 1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5, 1))
	btn.add_theme_font_size_override("font_size", 16)
	btn.text = text
	return btn


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_spacer(h: int) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, h)
	return sp
