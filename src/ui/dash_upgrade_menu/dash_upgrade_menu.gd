class_name DashUpgradeMenu
extends Control

## Winged Boots choice menu: pick 1 of 3 dash upgrades. Dash-only (charges,
## cooldown, range) — no damage-buffs after dashing; those belong to relics.

signal upgrade_selected(upgrade_id: String)

# The three dash upgrades Winged Boots can grant.
const UPGRADES: Array[Dictionary] = [
	{
		"id": "dash_charge",
		"title": "+1 Dash Charge",
		"desc": "Store an extra dash charge to use in a row.",
	},
	{
		"id": "dash_cooldown",
		"title": "Quicker Recovery",
		"desc": "Dash charges refill 25% faster.",
	},
	{
		"id": "dash_range",
		"title": "Longer Dash",
		"desc": "Dashes carry you 30% further.",
	},
]

@onready var title_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/Panel/Vertical/SubtitleLabel") as Label
@onready var choice_1: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice1") as Button
@onready var choice_2: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice2") as Button
@onready var choice_3: Button = get_node_or_null("CenterContainer/Panel/Vertical/Choice3") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("blocking_ui")
	visible = false
	_bind_buttons()


func _bind_buttons() -> void:
	if choice_1 and not choice_1.pressed.is_connected(_on_choice_pressed.bind(0)):
		choice_1.pressed.connect(_on_choice_pressed.bind(0))
	if choice_2 and not choice_2.pressed.is_connected(_on_choice_pressed.bind(1)):
		choice_2.pressed.connect(_on_choice_pressed.bind(1))
	if choice_3 and not choice_3.pressed.is_connected(_on_choice_pressed.bind(2)):
		choice_3.pressed.connect(_on_choice_pressed.bind(2))


func open_menu() -> void:
	visible = true
	_update_labels()
	_update_buttons()


func close_menu() -> void:
	visible = false


func _update_labels() -> void:
	if title_label:
		title_label.text = "Winged Boots!"
	if subtitle_label:
		subtitle_label.text = "Choose a dash upgrade."


func _update_buttons() -> void:
	var buttons: Array[Button] = [choice_1, choice_2, choice_3]
	for i: int in range(buttons.size()):
		var button: Button = buttons[i]
		if button == null:
			continue
		if i >= UPGRADES.size():
			button.text = "-"
			button.disabled = true
			continue
		var u: Dictionary = UPGRADES[i]
		button.text = "%s\n%s" % [u["title"], u["desc"]]
		button.disabled = false
		button.modulate = Color(0.7, 0.85, 1.0)


func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= UPGRADES.size():
		return
	upgrade_selected.emit(UPGRADES[index]["id"] as String)
