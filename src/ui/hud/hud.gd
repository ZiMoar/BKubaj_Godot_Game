class_name HUD
extends CanvasLayer

const PAUSE_MENU_SCENE: PackedScene = preload("res://src/ui/pause_menu/pause_menu.tscn")

@onready var xp_bar: ProgressBar = get_node_or_null("Control/TopBar/Header/Row/XPBar") as ProgressBar
@onready var difficulty_label: Label = get_node_or_null("Control/TopBar/Header/Row/DifficultyLabel") as Label
@onready var session_timer_label: Label = get_node_or_null("Control/TopBar/Header/Row/SessionTimerLabel") as Label
@onready var level_label: Label = get_node_or_null("Control/TopBar/Header/Row/LevelLabel") as Label
@onready var xp_text_label: Label = get_node_or_null("Control/TopBar/Header/Row/XPTextLabel") as Label
@onready var level_up_menu: LevelUpMenu = get_node_or_null("LevelUpMenu") as LevelUpMenu
@onready var weapon_choice_menu: WeaponChoiceMenu = get_node_or_null("WeaponChoiceMenu") as WeaponChoiceMenu
@onready var anvil_upgrade_menu: AnvilUpgradeMenu = get_node_or_null("AnvilUpgradeMenu") as AnvilUpgradeMenu
@onready var artefact_choice_menu: ArtefactChoiceMenu = get_node_or_null("ArtefactChoiceMenu") as ArtefactChoiceMenu
@onready var session_timer: Timer = get_node_or_null("SessionTimer") as Timer
@onready var boss_bar: ProgressBar = get_node_or_null("Control/BossBar") as ProgressBar
@onready var boss_name_label: Label = get_node_or_null("Control/BossBar/BossName") as Label
var active_boss: Node2D = null

@onready var primary_slot: WeaponSlotUI = get_node_or_null("Control/RightBar/Margin/WeaponContainer/PrimarySlot") as WeaponSlotUI
@onready var secondary_slot: WeaponSlotUI = get_node_or_null("Control/RightBar/Margin/WeaponContainer/SecondarySlot") as WeaponSlotUI
@onready var auto_slot_1: WeaponSlotUI = get_node_or_null("Control/RightBar/Margin/WeaponContainer/AutoSlot1") as WeaponSlotUI
@onready var auto_slot_2: WeaponSlotUI = get_node_or_null("Control/RightBar/Margin/WeaponContainer/AutoSlot2") as WeaponSlotUI
@onready var auto_slot_3: WeaponSlotUI = get_node_or_null("Control/RightBar/Margin/WeaponContainer/AutoSlot3") as WeaponSlotUI
@onready var art_slot_0: Label = get_node_or_null("Control/ArtefactBar/ArtSlot0") as Label
@onready var art_slot_1: Label = get_node_or_null("Control/ArtefactBar/ArtSlot1") as Label
@onready var art_slot_2: Label = get_node_or_null("Control/ArtefactBar/ArtSlot2") as Label
@onready var art_slot_3: Label = get_node_or_null("Control/ArtefactBar/ArtSlot3") as Label
@onready var art_slot_4: Label = get_node_or_null("Control/ArtefactBar/ArtSlot4") as Label
@onready var artefact_caption: Label = get_node_or_null("Control/ArtefactCaption") as Label
@onready var gold_label: Label = get_node_or_null("Control/GoldLabel") as Label

var current_player: Player = null
var pending_level_up_rewards: int = 0
var level_up_menu_open: bool = false
var current_level_number: int = 1
var session_elapsed_seconds: int = 0

# Class-mobility ability cooldown display (built at runtime to avoid scene-revert).
var ability_cd_bar: ProgressBar = null
var ability_cd_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_ensure_pause_menu()
	_ensure_ability_cooldown_ui()
	call_deferred("_initialize_hud")


## Builds a small bottom-centre panel showing the Space ability and its cooldown.
## Created in code (not the scene) so it works in every arena without editing
## scene files, mirroring the ESC pause-menu approach.
func _ensure_ability_cooldown_ui() -> void:
	if get_node_or_null("Control/AbilityCooldownHUD") != null:
		return
	var holder: Control = Control.new()
	holder.name = "AbilityCooldownHUD"
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.position = Vector2(-90, -70)
	holder.custom_minimum_size = Vector2(180, 40)

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	ability_cd_label = Label.new()
	ability_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_cd_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(ability_cd_label)

	ability_cd_bar = ProgressBar.new()
	ability_cd_bar.custom_minimum_size = Vector2(170, 8)
	ability_cd_bar.show_percentage = false
	ability_cd_bar.max_value = 1.0
	vbox.add_child(ability_cd_bar)

	holder.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	get_node("Control").add_child(holder)
	_update_ability_cooldown_display()


func _update_ability_cooldown_display() -> void:
	if ability_cd_bar == null or ability_cd_label == null:
		return
	if current_player == null:
		current_player = get_tree().get_first_node_in_group("player") as Player
	if current_player == null or not current_player.has_method("get_class_ability_name"):
		if ability_cd_label:
			ability_cd_label.text = ""
		return
	var name_: String = current_player.get_class_ability_name()
	if name_ == "":
		ability_cd_label.text = ""
		return
	var ratio: float = current_player.get_class_ability_cooldown_ratio()
	var ability_ready: bool = current_player.is_class_ability_ready()
	if ability_ready:
		ability_cd_label.text = "SPACE  ·  " + name_ + "  READY"
		ability_cd_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		ability_cd_bar.value = 1.0
		ability_cd_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.3, 0.9, 0.4)))
	else:
		ability_cd_label.text = "SPACE  ·  " + name_ + "  %.1fs" % (ratio * (ratio_cooldown_total()))
		ability_cd_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		ability_cd_bar.value = 1.0 - ratio
		ability_cd_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.85, 0.65, 0.2)))


## Total cooldown of the current ability, so the timer text shows real seconds.
func ratio_cooldown_total() -> float:
	if current_player == null:
		return 1.0
	var cfg: Dictionary = current_player.MOBILITY_CONFIG.get(current_player.get_class_ability_id(), {})
	return float(cfg.get("cooldown", 1.0))


func _make_bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	return sb


## Adds the ESC pause overlay as a child so it works in every arena without
## needing to edit each arena scene (avoids the editor-revert issue).
func _ensure_pause_menu() -> void:
	if get_node_or_null("PauseMenu") != null:
		return
	var pause_menu: PauseMenu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

func _initialize_hud() -> void:
	_connect_to_xp_manager()
	_connect_to_player()
	_connect_to_level_up_menu()
	_connect_to_session_timer()

func _connect_to_xp_manager() -> void:
	var manager = get_tree().get_first_node_in_group("team_xp_manager") as TeamXPManager
	if manager:
		if not manager.team_xp_changed.is_connected(_on_xp_changed):
			manager.team_xp_changed.connect(_on_xp_changed)
		if not manager.team_leveled_up.is_connected(_on_level_up):
			manager.team_leveled_up.connect(_on_level_up)
		_on_xp_changed(manager.current_xp, manager.xp_to_next_level)
		current_level_number = manager.team_level
		if level_label:
			level_label.text = "Team Lv. " + str(manager.team_level)
		_update_difficulty_meter()
		_update_session_timer_label()

func _connect_to_player() -> void:
	current_player = get_tree().get_first_node_in_group("player") as Player
	if current_player:
		_setup_weapon_slots(current_player)
		_update_difficulty_meter()
		_update_artefact_slots()
		if not current_player.weapons_changed.is_connected(_on_weapons_changed):
			current_player.weapons_changed.connect(_on_weapons_changed)
		if not current_player.artefacts_changed.is_connected(_on_artefacts_changed):
			current_player.artefacts_changed.connect(_on_artefacts_changed)
		if current_player.has_signal("gold_changed") and not current_player.gold_changed.is_connected(_on_gold_changed):
			current_player.gold_changed.connect(_on_gold_changed)
		if gold_label:
			gold_label.text = "🪙 %d" % current_player.get_gold()

func _connect_to_level_up_menu() -> void:
	if level_up_menu and not level_up_menu.upgrade_selected.is_connected(_on_upgrade_selected):
		level_up_menu.upgrade_selected.connect(_on_upgrade_selected)
	if weapon_choice_menu and not weapon_choice_menu.weapon_selected.is_connected(_on_weapon_choice_selected):
		weapon_choice_menu.weapon_selected.connect(_on_weapon_choice_selected)
	if anvil_upgrade_menu and not anvil_upgrade_menu.upgrade_applied.is_connected(_on_anvil_upgrade_applied):
		anvil_upgrade_menu.upgrade_applied.connect(_on_anvil_upgrade_applied)
	if artefact_choice_menu and not artefact_choice_menu.artefact_selected.is_connected(_on_artefact_choice_selected):
		artefact_choice_menu.artefact_selected.connect(_on_artefact_choice_selected)

func _connect_to_session_timer() -> void:
	if session_timer and not session_timer.timeout.is_connected(_on_session_timer_timeout):
		session_timer.timeout.connect(_on_session_timer_timeout)

func _on_weapons_changed() -> void:
	_setup_weapon_slots(current_player)

func _on_artefacts_changed() -> void:
	_update_artefact_slots()

func _on_gold_changed(current_gold: int) -> void:
	if gold_label:
		gold_label.text = "🪙 %d" % current_gold


func _update_artefact_slots() -> void:
	var slots: Array[Label] = [art_slot_0, art_slot_1, art_slot_2, art_slot_3, art_slot_4]
	var count: int = current_player.get_artefact_count() if current_player else 0
	var capacity: int = current_player.get_artefact_slot_capacity() if current_player else 5
	for i: int in range(slots.size()):
		var slot: Label = slots[i] as Label
		if slot == null:
			continue
		if i < count:
			slot.text = "◆"
			slot.add_theme_color_override("font_color", current_player.get_artefact_slot_color(i))
		else:
			slot.text = "◇"
			slot.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	if artefact_caption:
		artefact_caption.text = "Artifacts (%d/%d)" % [count, capacity]


func _setup_weapon_slots(player: Node2D) -> void:
	var weapons_container = player.get_node_or_null("Weapons")
	if weapons_container == null:
		return

	# Clear all slots first
	if primary_slot: primary_slot.unbind_weapon()
	if secondary_slot: secondary_slot.unbind_weapon()
	if auto_slot_1: auto_slot_1.unbind_weapon()
	if auto_slot_2: auto_slot_2.unbind_weapon()
	if auto_slot_3: auto_slot_3.unbind_weapon()

	var auto_index = 0
	var auto_slots = [auto_slot_1, auto_slot_2, auto_slot_3]

	for weapon in weapons_container.get_children():
		if weapon is Weapon:
			match weapon.trigger_type:
				Weapon.TriggerType.PRIMARY:
					if primary_slot: primary_slot.bind_weapon(weapon)
				Weapon.TriggerType.SECONDARY:
					if secondary_slot: secondary_slot.bind_weapon(weapon)
				Weapon.TriggerType.AUTOMATIC:
					if auto_index < auto_slots.size() and auto_slots[auto_index]:
						auto_slots[auto_index].bind_weapon(weapon)
						auto_index += 1

func _on_xp_changed(current: int, max_xp: int) -> void:
	if xp_bar:
		xp_bar.max_value = max_xp
		var tween = create_tween()
		tween.tween_property(xp_bar, "value", current, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if xp_text_label:
		xp_text_label.text = str(current) + " / " + str(max_xp) + " XP"
	_update_difficulty_meter()

func _on_level_up(new_level: int) -> void:
	current_level_number = new_level
	if level_label:
		level_label.text = "Team Lv. " + str(new_level)
		var tween = create_tween()
		tween.tween_property(level_label, "scale", Vector2(1.2, 1.2), 0.15)
		tween.tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.15)
	_update_difficulty_meter()

	pending_level_up_rewards += 1
	if not level_up_menu_open:
		_show_level_up_menu(new_level)

func _show_level_up_menu(new_level: int) -> void:
	if level_up_menu == null:
		return

	if current_player == null:
		current_player = get_tree().get_first_node_in_group("player") as Player
		if current_player == null:
			return

	level_up_menu_open = true
	get_tree().paused = true
	level_up_menu.open_for_player(current_player, new_level)

func _on_upgrade_selected(upgrade_id: String, rarity: int) -> void:
	if current_player and current_player.has_method("apply_upgrade"):
		current_player.apply_upgrade(upgrade_id, rarity)
		_update_difficulty_meter()

	pending_level_up_rewards = max(0, pending_level_up_rewards - 1)
	if pending_level_up_rewards > 0:
		if level_up_menu:
			level_up_menu.close_menu()
		call_deferred("_reopen_level_up_menu")
	else:
		_close_level_up_menu()

func _reopen_level_up_menu() -> void:
	if level_up_menu == null:
		return

	if current_player == null:
		current_player = get_tree().get_first_node_in_group("player") as Player
		if current_player == null:
			return

	level_up_menu.open_for_player(current_player, current_level_number)

func _close_level_up_menu() -> void:
	level_up_menu_open = false
	if level_up_menu:
		level_up_menu.close_menu()
	get_tree().paused = false


# --- Weapon Choice (Treasure Chest) ---

func show_weapon_choice() -> void:
	if weapon_choice_menu == null or current_player == null:
		return

	get_tree().paused = true
	weapon_choice_menu.open_menu()


func _on_weapon_choice_selected(weapon_scene: PackedScene) -> void:
	if current_player and current_player.has_method("add_weapon"):
		current_player.add_weapon(weapon_scene)
	weapon_choice_menu.close_menu()
	get_tree().paused = false


# --- Anvil Upgrade (upgrade a specific weapon's stats) ---

func show_anvil_upgrade() -> void:
	if anvil_upgrade_menu == null or current_player == null:
		return
	get_tree().paused = true
	anvil_upgrade_menu.open_menu()


func _on_anvil_upgrade_applied(_weapon: Weapon, _stat_id: String) -> void:
	anvil_upgrade_menu.close_menu()
	get_tree().paused = false


# --- Artefact Choice (Boss Relic) ---

func show_artefact_choice() -> void:
	if artefact_choice_menu == null or current_player == null:
		# fall back to looking the player up in case HUD initialised early
		current_player = get_tree().get_first_node_in_group("player") as Player
		if artefact_choice_menu == null or current_player == null:
			return
	if current_player.get_artefact_count() >= current_player.get_artefact_slot_capacity():
		return

	get_tree().paused = true
	artefact_choice_menu.open_for_player(current_player)


func _on_artefact_choice_selected(artefact_id: String) -> void:
	if current_player and current_player.has_method("add_artefact"):
		current_player.add_artefact(artefact_id)
	artefact_choice_menu.close_menu()
	get_tree().paused = false

func _on_difficulty_timer_timeout() -> void:
	pass

func _on_session_timer_timeout() -> void:
	if get_tree().paused:
		return

	var prev_minutes: int = int(session_elapsed_seconds / 60.0)
	session_elapsed_seconds += 1
	var new_minutes: int = int(session_elapsed_seconds / 60.0)

	if current_player == null:
		current_player = get_tree().get_first_node_in_group("player") as Player
	# Difficulty advances once per minute, so it ramps slowly.
	if current_player and current_player.has_method("advance_runtime_difficulty") and new_minutes > prev_minutes:
		current_player.advance_runtime_difficulty(current_player.difficulty_runtime_per_minute)
	_update_difficulty_meter()
	_update_session_timer_label()

func _update_difficulty_meter() -> void:
	if current_player == null:
		current_player = get_tree().get_first_node_in_group("player") as Player
	if current_player == null:
		return

	var difficulty_value = maxf(0.0, current_player.difficulty)
	if current_player.has_method("get_map_difficulty"):
		difficulty_value = maxf(0.0, float(current_player.get_map_difficulty()))
	if difficulty_label:
		difficulty_label.text = "Map Difficulty: %.0f" % difficulty_value

func _update_session_timer_label() -> void:
	if session_timer_label == null:
		return

	@warning_ignore("integer_division")
	var minutes: int = session_elapsed_seconds / 60
	var seconds: int = session_elapsed_seconds % 60
	session_timer_label.text = "Session: %02d:%02d" % [minutes, seconds]


# --- Boss Health Bar ---

func register_boss(boss: Node2D) -> void:
	active_boss = boss
	if boss_bar:
		boss_bar.visible = true
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.current_health
	if boss_name_label and "boss_display_name" in boss:
		boss_name_label.text = str(boss.boss_display_name)


func _process(_delta: float) -> void:
	_update_ability_cooldown_display()
	if active_boss and is_instance_valid(active_boss):
		if boss_bar:
			boss_bar.max_value = active_boss.max_health
			boss_bar.value = active_boss.current_health
	else:
		if boss_bar and boss_bar.visible:
			boss_bar.visible = false
		if active_boss:
			active_boss = null
