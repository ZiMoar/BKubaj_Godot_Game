class_name WeaponSlotUI
extends PanelContainer

@export var slot_badge: String = "LMB"

@onready var badge_label: Label = get_node_or_null("Margin/Row/BadgeLabel") as Label
@onready var name_label: Label = get_node_or_null("Margin/Row/NameLabel") as Label
@onready var type_label: Label = get_node_or_null("Margin/Row/TypeLabel") as Label
@onready var cooldown_bar: ProgressBar = get_node_or_null("CooldownBar") as ProgressBar

var bound_weapon: Weapon = null

func _ready() -> void:
	if badge_label:
		badge_label.text = slot_badge
	if cooldown_bar:
		cooldown_bar.value = 0.0

func unbind_weapon() -> void:
	if bound_weapon and is_instance_valid(bound_weapon):
		if bound_weapon.cooldown_started.is_connected(_on_cooldown_started):
			bound_weapon.cooldown_started.disconnect(_on_cooldown_started)
	bound_weapon = null
	if name_label: name_label.text = "-"
	if type_label: type_label.text = ""
	if cooldown_bar: cooldown_bar.value = 0.0


func bind_weapon(weapon: Weapon) -> void:
	if bound_weapon and is_instance_valid(bound_weapon):
		if bound_weapon.cooldown_started.is_connected(_on_cooldown_started):
			bound_weapon.cooldown_started.disconnect(_on_cooldown_started)
			
	bound_weapon = weapon
	
	if weapon == null:
		if name_label: name_label.text = "-"
		if cooldown_bar: cooldown_bar.value = 0.0
		return
		
	if name_label:
		name_label.text = weapon.weapon_name  # Full name; widest slots show ellipsis if needed

	if type_label and "damage_type" in weapon:
		type_label.text = DamageType.display_name(weapon.damage_type)
		type_label.add_theme_color_override("font_color", DamageType.color_for(weapon.damage_type))

	weapon.cooldown_started.connect(_on_cooldown_started)

func _on_cooldown_started(duration: float) -> void:
	if cooldown_bar:
		cooldown_bar.value = 100.0
		var tween = create_tween()
		tween.tween_property(cooldown_bar, "value", 0.0, duration)
