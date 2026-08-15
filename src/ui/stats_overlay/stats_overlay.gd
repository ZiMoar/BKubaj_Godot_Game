class_name StatsOverlay
extends Control

## Mid-run character stats overlay. Toggle with a hotkey (KEY_TAB) while
## playing, or open it from the pause menu. Reads live stats off the player
## node and renders them as a labelled two-column list. Pauses the game while
## open so the player can read safely.

const TOGGLE_KEY: Key = KEY_TAB

const ARTEFACTS: Script = preload("res://src/systems/artefact.gd")

@onready var stats_box: VBoxContainer = get_node_or_null("CenterContainer/Panel/Vertical/Scroll/StatsBox") as VBoxContainer
@onready var close_button: Button = get_node_or_null("CenterContainer/Panel/Vertical/CloseButton") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == TOGGLE_KEY:
			if visible:
				close()
			else:
				open()
			get_viewport().set_input_as_handled()


func open() -> void:
	_populate()
	visible = true
	get_tree().paused = true
	if close_button:
		close_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	_clear()


## Rebuild the stat rows from the live player state.
func _populate() -> void:
	_clear()
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		_add_stat("Player", "not found")
		return

	var health_max: int = int(player.call("current_max_health")) if player.has_method("current_max_health") else 100
	var health_cur: int = int(player.get("current_health"))
	var crit_chance: float = float(player.get("critical_hit_chance")) * 100.0
	var crit_mult: float = float(player.call("get_critical_multiplier")) if player.has_method("get_critical_multiplier") else 2.0
	var might_mult: float = float(player.call("get_might_multiplier")) if player.has_method("get_might_multiplier") else 1.0
	var as_mult: float = float(player.call("get_attack_speed_multiplier")) if player.has_method("get_attack_speed_multiplier") else 1.0
	var area_mult: float = float(player.call("get_area_multiplier")) if player.has_method("get_area_multiplier") else 1.0
	var cd_mult: float = float(player.call("get_cooldown_multiplier")) if player.has_method("get_cooldown_multiplier") else 1.0
	var pierce: int = int(player.call("get_extra_pierce")) if player.has_method("get_extra_pierce") else 0
	var difficulty: float = float(player.call("get_map_difficulty")) if player.has_method("get_map_difficulty") else 0.0
	var armor: float = float(player.call("current_armor")) if player.has_method("current_armor") else 0.0
	var dr_mult: float = float(player.call("get_damage_reduction_multiplier")) if player.has_method("get_damage_reduction_multiplier") else 1.0
	var thorns: float = float(player.call("get_thorns_damage")) if player.has_method("get_thorns_damage") else 0.0

	_add_section("Vitals")
	_add_stat("Health", "%d / %d" % [health_cur, health_max])
	_add_stat("HP regen /s", "%.1f" % float(player.get("hp_regen_per_second")))
	_add_stat("Armor", "%.1f" % armor)
	_add_stat("Damage reduction", "%d%%" % int(round((1.0 - dr_mult) * 100.0)))
	_add_stat("Evasion", "%d%%" % int(round(float(player.get("evasion_chance")) * 100.0)))
	_add_stat("Lifesteal", "%.1f" % float(player.get("lifesteal_flat")))
	_add_stat("Thorns", "%.1f" % thorns)
	_add_stat("Shield", "%.1f" % float(player.get("shield_capacity")))

	_add_section("Offense")
	_add_stat("Damage (might)", "%+d%%" % int(round((might_mult - 1.0) * 100.0)))
	_add_stat("Attack speed", "%d%%" % int(round(as_mult * 100.0)))
	_add_stat("Crit chance", "%d%%" % int(round(crit_chance)))
	_add_stat("Crit damage", "%.1fx" % crit_mult)
	_add_stat("Area", "%+d%%" % int(round((area_mult - 1.0) * 100.0)))
	_add_stat("Cooldowns", "%d%%" % int(round(cd_mult * 100.0)))
	_add_stat("Pierce", "%d" % pierce)
	_add_stat("Ailment chance", "%d%%" % int(round(float(player.get("ailment_chance")) * 100.0)))

	_add_section("Utility")
	_add_stat("Move speed", "%+d%%" % int(round(float(player.get("move_speed_percent_bonus")) * 100.0)))
	_add_stat("Gold", "%d" % int(player.get("gold")))
	_add_stat("Luck", "%d%%" % int(round(float(player.get("luck")) * 100.0)))
	_add_stat("Magnet", "on" if bool(player.get("magnet_enabled")) else "off")
	_add_stat("Dash charges", "%d" % int(player.get("dash_charges")))

	_add_section("Run")
	_add_stat("Difficulty", "%.1f" % difficulty)
	var relic_count: int = 0
	if player.has_method("get_artefact_count"):
		relic_count = int(player.call("get_artefact_count"))
	_add_stat("Relics", "%d" % relic_count)

	if relic_count > 0:
		_add_relic_listing(player)


## Lists the player's currently-equipped relics with their names + descriptions.
func _add_relic_listing(player: Node) -> void:
	_add_section("Relics")
	for i: int in range(int(player.call("get_artefact_count"))):
		var id: String = player.call("get_artefact_at_slot", i)
		if id.is_empty():
			continue
		var name_text: String = ARTEFACTS.get_display_name(id) if ARTEFACTS != null else id
		var desc: String = ARTEFACTS.get_description(id) if ARTEFACTS != null else ""
		var colour: Color = player.call("get_artefact_slot_color", i)
		_add_relic_row(i + 1, name_text, desc, colour)


func _add_relic_row(index: int, name_text: String, desc: String, colour: Color) -> void:
	if stats_box == null:
		return
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var idx := Label.new()
	idx.text = "%d." % index
	idx.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	idx.add_theme_font_size_override("font_size", 13)
	var nm := Label.new()
	nm.text = name_text
	nm.add_theme_color_override("font_color", colour)
	nm.add_theme_font_size_override("font_size", 13)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(idx)
	name_row.add_child(nm)
	stats_box.add_child(name_row)
	if not desc.is_empty():
		var desc_l := Label.new()
		desc_l.text = desc
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_l.add_theme_font_size_override("font_size", 11)
		desc_l.add_theme_constant_override("line_separation", 0)
		desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 24)
		indent.add_theme_constant_override("margin_right", 4)
		indent.add_child(desc_l)
		stats_box.add_child(indent)


func _add_section(title: String) -> void:
	if stats_box == null:
		return
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(1, 0.84, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 13)
	stats_box.add_child(label)


func _add_stat(label_text: String, value_text: String) -> void:
	if stats_box == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_l := Label.new()
	name_l.text = label_text
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_l.add_theme_font_size_override("font_size", 12)
	var val_l := Label.new()
	val_l.text = value_text
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_l.add_theme_color_override("font_color", Color(1, 0.84, 0.35))
	val_l.add_theme_font_size_override("font_size", 12)
	row.add_child(name_l)
	row.add_child(val_l)
	stats_box.add_child(row)


func _clear() -> void:
	if stats_box == null:
		return
	for child in stats_box.get_children():
		child.queue_free()


func _on_close_pressed() -> void:
	close()
