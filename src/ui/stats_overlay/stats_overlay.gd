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

## True when this overlay was opened from the pause menu (which hid itself).
## On close we must restore the pause menu, otherwise the game stays paused with
## nothing visible (a soft-lock).
var _opened_from_pause: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("blocking_ui")
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


func open(from_pause: bool = false) -> void:
	_opened_from_pause = from_pause
	_populate()
	visible = true
	PauseCoord.begin_block()
	if close_button:
		close_button.grab_focus()


func close() -> void:
	visible = false
	PauseCoord.end_block()
	_clear()
	# If we were opened from the pause menu (which hid itself), bring it back so
	# the player isn't left staring at a paused but empty screen.
	if _opened_from_pause:
		_opened_from_pause = false
		_restore_pause_menu()


## Re-show the pause menu after closing stats that were opened from it.
func _restore_pause_menu() -> void:
	var pause_menu: Control = get_node_or_null("../PauseMenu") as Control
	if pause_menu == null:
		return
	pause_menu.visible = true
	var resume_button: Button = pause_menu.get_node_or_null("CenterContainer/Panel/Vertical/ResumeButton") as Button
	if resume_button:
		resume_button.grab_focus()


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

	_add_subclass_listing(player)

	_add_section("Vitals")
	_add_stat("Health", "%d / %d" % [health_cur, health_max])
	_add_stat("HP regen /s", "%.1f" % float(player.get("hp_regen_per_second")))
	_add_stat("Armor", "%.1f" % armor)
	_add_stat("Damage reduction", "%d%%" % int(round((1.0 - dr_mult) * 100.0)))
	_add_stat("Evasion", "%.0f" % float(player.get("evasion_chance")))
	var dodge_chance: float = float(player.call("get_evasion_dodge_chance")) if player.has_method("get_evasion_dodge_chance") else 0.0
	_add_stat("Dodge chance", "%d%%" % int(round(dodge_chance * 100.0)))
	_add_stat("Lifesteal", "%.1f" % float(player.get("lifesteal_flat")))
	_add_stat("Thorns", "%.1f" % thorns)
	_add_stat("Shield", "%.1f" % float(player.get("shield_capacity")))
	var revive_count: int = int(player.get("revive_count"))
	if revive_count > 0:
		_add_stat("Revives", "%d" % revive_count)

	_add_section("Offense")
	_add_stat("Damage (might)", "%+d%%" % int(round((might_mult - 1.0) * 100.0)))
	var power_flat: float = float(player.get("might_flat_bonus"))
	if power_flat != 0.0:
		_add_stat("Power", "+%.0f" % power_flat)
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
	_add_stat("Luck", "%d" % int(player.get("luck")))
	if bool(player.get("magnet_enabled")):
		_add_stat("Magnet", "%.0f px" % float(player.get("magnet_range")))
	else:
		_add_stat("Magnet", "off")
	var growth: float = float(player.get("growth_percent_bonus"))
	if growth != 0.0:
		_add_stat("XP gain", "%+d%%" % int(round(growth * 100.0)))
	var greed: float = float(player.get("greed_percent_bonus"))
	if greed != 0.0:
		_add_stat("Gold gain", "%+d%%" % int(round(greed * 100.0)))
	_add_stat("Rerolls", "%d" % int(player.get("rerolls")))
	var banish_count: int = int(player.get("banish_count"))
	if banish_count > 0:
		_add_stat("Banish", "%d" % banish_count)
	_add_stat("Dash charges", "%d" % int(player.get("dash_charges")))
	var dash_cd: float = float(player.get("dash_cooldown"))
	if dash_cd > 0.0:
		_add_stat("Dash CD", "-%d%%" % int(round(dash_cd * 100.0)))
	var dash_range: float = float(player.get("dash_range_bonus"))
	if dash_range > 0.0:
		_add_stat("Dash range", "+%d%%" % int(round(dash_range * 100.0)))

	_add_section("Run")
	_add_stat("Difficulty", "%.1f" % difficulty)
	var relic_count: int = 0
	if player.has_method("get_artefact_count"):
		relic_count = int(player.call("get_artefact_count"))
	_add_stat("Relics", "%d" % relic_count)

	if relic_count > 0:
		_add_relic_listing(player)

	_add_weapon_listing(player)


## Shows the run's chosen subclass (from the Altar of Ascension, room 10) and a
## short description of its effect, so the player can see their ascension and
## what it does at a glance.
func _add_subclass_listing(_player: Node) -> void:
	if stats_box == null:
		return
	var state: Node = get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_selected_subclass"):
		return
	var sub: Node = state.get_selected_subclass()
	if sub == null:
		return
	_add_section("Subclass")
	var name_l := Label.new()
	name_l.text = str(sub.get("display_name"))
	name_l.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_l.add_theme_constant_override("outline_size", 1)
	name_l.add_theme_font_size_override("font_size", 13)
	stats_box.add_child(name_l)
	var desc: String = str(sub.get("description"))
	if not desc.is_empty():
		var desc_l := Label.new()
		desc_l.text = desc
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		desc_l.add_theme_font_size_override("font_size", 11)
		desc_l.add_theme_constant_override("line_separation", 0)
		desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_box.add_child(desc_l)


## Lists every equipped weapon with its per-weapon anvil/signature stat bonuses.
## These live on each weapon (not the player), so they're aggregated here per
## weapon so the player can see what upgrades each one has taken.
func _add_weapon_listing(player: Node) -> void:
	var weapons: Node = player.get_node_or_null("Weapons")
	if weapons == null:
		return
	var weapon_nodes: Array = weapons.get_children()
	if weapon_nodes.is_empty():
		return
	_add_section("Weapons")
	for weapon: Node in weapon_nodes:
		_add_weapon_block(weapon)


func _add_weapon_block(weapon: Node) -> void:
	if stats_box == null:
		return
	var nm: String = str(weapon.get("weapon_name")) if weapon.get("weapon_name") != null else str(weapon.name)
	var name_l := Label.new()
	name_l.text = nm
	name_l.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_l.add_theme_constant_override("outline_size", 1)
	name_l.add_theme_font_size_override("font_size", 13)
	stats_box.add_child(name_l)

	if weapon.get("damage_type") != null:
		_add_stat("Type", DamageType.display_name(int(weapon.get("damage_type"))))

	var specs: Array = [
		["Proj. count", "projectile_count_bonus", false],
		["Proj. chance", "projectile_extra_chance", true],
		["Pierce", "pierce_bonus", false],
		["Chain", "chain_count_bonus", false],
		["Area", "area_bonus", true],
		["Repeat", "repeat_chance", true],
		["Damage", "damage_percent_bonus", true],
		["Proj. speed", "projectile_speed_bonus", true],
		["Duration", "duration_bonus", true],
		["Explosion", "explosion_on_kill_chance", true],
		["Knockback", "knockback_bonus", true],
		["Ailment effect", "ailment_effect_bonus", true],
		["Close dmg", "close_range_damage_bonus", true],
		["Far dmg", "far_range_damage_bonus", true],
	]
	for s: Array in specs:
		var label: String = str(s[0])
		var key: String = str(s[1])
		var pct: bool = bool(s[2])
		var raw = weapon.get(key)
		var val: float = float(raw) if raw != null else 0.0
		if val == 0.0:
			continue
		if pct:
			_add_stat(label, "%+d%%" % int(round(val * 100.0)))
		else:
			_add_stat(label, "%+d" % int(round(val)))

	var upg: int = int(weapon.get("anvil_upgrade_count")) if weapon.get("anvil_upgrade_count") != null else 0
	if upg > 0:
		_add_stat("Anvil upgrades", "%d" % upg)


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
