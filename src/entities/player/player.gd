class_name Player
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal weapons_changed()
signal artefacts_changed()
signal gold_changed(current_gold: int)

const ARTEFACTS: Script = preload("res://src/systems/artefact.gd")

# --- Player Stats ---
@export_category("Offense")
@export var might_flat_bonus: float = 0.0
@export var might_percent_bonus: float = 0.0
@export var attack_speed_bonus: float = 0.0
@export var critical_hit_chance: float = 0.0
@export var critical_hit_damage_multiplier: float = 2.0
@export var area_bonus: float = 0.0
@export var projectile_speed_bonus: float = 0.0
@export var duration_bonus: float = 0.0
@export var amount_bonus: int = 0
@export var armor_penetration_flat_bonus: float = 0.0
@export var armor_penetration_percent_bonus: float = 0.0

@export_category("Survival & Defense")
@export var max_health: int = 100
@export var max_health_bonus: int = 0
@export var hp_regen_per_second: float = 0.0
@export var armor: float = 0.0
@export var evasion_chance: float = 0.0
@export var lifesteal_flat: float = 0.0
@export var revive_count: int = 0
@export var revive_health_percent: float = 0.25
@export var thorns_flat: float = 0.0
@export var shield_capacity: float = 0.0

@export_category("Utility & Movement")
@export var speed: float = 200.0
@export var move_speed_percent_bonus: float = 0.0
@export var magnet_enabled: bool = false
@export_range(0.0, 2000.0, 1.0) var magnet_range: float = 50.0
@export var dash_charges: int = 1
@export var dash_cooldown: float = 0.0
@export var invincibility_duration: float = 0.5
@export var invincibility_frame_bonus: float = 0.0

@export_category("Progression & Meta")
@export var growth_percent_bonus: float = 0.0
@export var greed_percent_bonus: float = 0.0
@export var luck: float = 0.0
@export var gold: int = 0
@export var rerolls: int = 0
@export var banish_count: int = 0
@export var difficulty: float = 0.0
# Difficulty grows ONCE PER MINUTE instead of per second, so the number ramps
# slowly. Enemy stat scaling is boosted to compensate (see enemies' *_per_difficulty).
@export var difficulty_runtime_per_minute: float = 1.0
@export var pierce_bonus: int = 0

@export_category("Reserved")
@export var shield_placeholder: float = 0.0

var current_health: int
var is_invincible: bool = false
var current_move_input: Vector2 = Vector2.ZERO
var revive_remaining: int = 0
var hp_regen_bank: float = 0.0
var difficulty_runtime_bonus: float = 0.0
var _lifesteal_cooldown_remaining: float = 0.0
const LIFESTEAL_COOLDOWN: float = 0.1

# --- Artefact system ---
const MAX_ARTEFACT_SLOTS: int = 5
# Artefact IDs (see Artefact class registry).
const ARTEFACT_ARMOR_TO_THORNS: String = "armor_to_thorns"
const ARTEFACT_LIFESTEAL_CRIT: String = "lifesteal_crit"
const ARTEFACT_LIFESTEAL_TO_DAMAGE: String = "lifesteal_to_damage"
const ARTEFACT_MAXHP_TO_ARMOR: String = "maxhp_to_armor"
const ARTEFACT_REGEN_TO_ATTACK_SPEED: String = "regen_to_attack_speed"
const ARTEFACT_THORNS_TO_DAMAGE: String = "thorns_to_damage"
# Cross-interaction scaling factors for the artefact effects.
const IRON_HEART_ARMOR_RATIO: float = 0.20
const REGEN_TO_ATTACK_SPEED_FACTOR: float = 5.0
const LIFESTEAL_TO_DAMAGE_PER_UNIT: float = 0.03
const THORNS_TO_DAMAGE_PER_UNIT: float = 0.02

var artefact_ids: Array[String] = []

# --- Node References ---
@onready var weapons_container: Node2D = $Weapons
@onready var hp_bar: Control = get_node_or_null("HPBar")
@onready var sprite: Sprite2D = $Sprite2D
@onready var magnet_area: Area2D = get_node_or_null("MagnetArea") as Area2D
@onready var magnet_shape: CollisionShape2D = get_node_or_null("MagnetArea/CollisionShape2D") as CollisionShape2D
@onready var hp_value_label: Label = null

func _ready() -> void:
	revive_remaining = revive_count
	current_health = max_health + max_health_bonus
	if hp_bar:
		hp_bar.max_value = current_max_health()
		hp_bar.value = current_health
		_ensure_hp_value_label()
		_update_hp_value_label()
		
	call_deferred("_emit_initial_health")
	
	# Fail-safe group registration for enemies
	if not is_in_group("player"):
		add_to_group("player")

	if magnet_area and not magnet_area.area_entered.is_connected(_on_magnet_area_entered):
		magnet_area.area_entered.connect(_on_magnet_area_entered)

	_apply_magnet_settings()

	# Give the player the Primary + Secondary weapons for the chosen class.
	_setup_class_starting_weapons()

func _emit_initial_health() -> void:
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()

func get_might_multiplier() -> float:
	return maxf(0.0, 1.0 + might_percent_bonus)

func get_attack_speed_multiplier() -> float:
	# Diminishing returns: 100/(100+x). x=100 -> 0.5x cooldown, x=300 -> 0.25x
	var bonus: float = attack_speed_bonus
	if has_artefact(ARTEFACT_REGEN_TO_ATTACK_SPEED):
		bonus += hp_regen_per_second * REGEN_TO_ATTACK_SPEED_FACTOR
	return 100.0 / (100.0 + maxf(0.0, bonus))

# Flat armor with the same diminishing-returns formula as attack speed.
# Subclasses/artefacts can inflate armor (the value returned here) without
# changing how the mitigation formula itself works.
func current_armor() -> float:
	var value: float = maxf(0.0, armor)
	if has_artefact(ARTEFACT_MAXHP_TO_ARMOR):
		value += float(current_max_health()) * IRON_HEART_ARMOR_RATIO
	return value

func get_damage_reduction_multiplier() -> float:
	return 100.0 / (100.0 + current_armor())

# Thorns damage actually reflected to attackers. Artefacts can scale it off
# other defensive stats (e.g. armor).
func get_thorns_damage() -> float:
	var value: float = maxf(0.0, thorns_flat)
	if has_artefact(ARTEFACT_ARMOR_TO_THORNS):
		value += current_armor()
	return value

func get_critical_multiplier() -> float:
	return maxf(1.0, critical_hit_damage_multiplier)

func roll_critical_hit() -> bool:
	return randf() < clamp(critical_hit_chance, 0.0, 1.0)

func get_attack_damage(base_damage: float) -> int:
	var flat_applied = maxf(0.0, base_damage + might_flat_bonus)
	var damage = flat_applied * get_might_multiplier()
	# Cross-stat artefacts scale outgoing damage off defensive/utility stats.
	if has_artefact(ARTEFACT_LIFESTEAL_TO_DAMAGE):
		damage *= 1.0 + lifesteal_flat * LIFESTEAL_TO_DAMAGE_PER_UNIT
	if has_artefact(ARTEFACT_THORNS_TO_DAMAGE):
		damage *= 1.0 + thorns_flat * THORNS_TO_DAMAGE_PER_UNIT
	return max(0, int(round(damage)))

func get_map_difficulty() -> float:
	return maxf(0.0, difficulty + difficulty_runtime_bonus)

# Area stat: scales the radius of AOE skills and the size of projectiles.
# Linear multiplier (1.0 = base). "+50% area" means skills/projectiles are 50% bigger.
func get_area_multiplier() -> float:
	return maxf(0.25, 1.0 + area_bonus)

func advance_runtime_difficulty(amount: float) -> void:
	difficulty_runtime_bonus = maxf(0.0, difficulty_runtime_bonus + amount)


# Extra enemies piercing projectiles can pass through. Placeholder hook so a
# future stat or upgrade can raise it.
func get_extra_pierce() -> int:
	return maxi(0, pierce_bonus)


# Global cooldown multiplier (default 1.0). Mana Overload (mage) sets it to
# 0.5 to halve every weapon's cooldown while its buff is active.
var _cooldown_multiplier: float = 1.0

func get_cooldown_multiplier() -> float:
	return maxf(0.05, _cooldown_multiplier)

func set_cooldown_multiplier(value: float) -> void:
	_cooldown_multiplier = maxf(0.05, value)

func apply_lifesteal() -> void:
	if lifesteal_flat <= 0.0 or current_health <= 0:
		return
	if _lifesteal_cooldown_remaining > 0.0:
		return

	_lifesteal_cooldown_remaining = LIFESTEAL_COOLDOWN
	var heal_amount: float = lifesteal_flat * get_might_multiplier()
	# Vampiric Rage artefact: lifesteal heal can roll crit for double healing.
	if has_artefact(ARTEFACT_LIFESTEAL_CRIT) and roll_critical_hit():
		heal_amount *= get_critical_multiplier()
	heal(heal_amount)

func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0:
		return

	current_health = min(current_max_health(), int(round(current_health + amount)))
	if hp_bar:
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()

const MAX_AUTO_WEAPONS: int = 3

## Equips the class-defined Primary + Secondary weapons. Reads the class
## chosen in the main menu's class-selection screen (GameState autoload).
func _setup_class_starting_weapons() -> void:
	if weapons_container == null:
		return
	var state: Node = get_node_or_null("/root/GameState")
	if state == null:
		return
	var cls: Dictionary = state.get_selected_class()
	var scenes: Array = [cls.get("primary", null), cls.get("secondary", null)]
	for scene in scenes:
		var ws: PackedScene = scene as PackedScene
		if ws == null:
			continue
		var weapon: Node = ws.instantiate()
		weapons_container.add_child(weapon)
		if weapon is Weapon and weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
			weapon.call_deferred("try_fire")
	weapons_changed.emit()


func count_automatic_weapons() -> int:
	var count: int = 0
	for existing in weapons_container.get_children():
		if existing is Weapon and existing.trigger_type == Weapon.TriggerType.AUTOMATIC:
			count += 1
	return count

func can_add_weapon(weapon_scene: PackedScene) -> bool:
	if weapon_scene == null:
		return false
	# Cap only the automatic (chest-earned) weapons; starting primary/secondary don't count
	if count_automatic_weapons() >= MAX_AUTO_WEAPONS:
		return false
	# Prevent taking multiple copies of the same weapon
	for existing in weapons_container.get_children():
		if existing is Weapon and existing.scene_file_path == weapon_scene.resource_path:
			return false
	return true

func add_weapon(weapon_scene: PackedScene) -> Weapon:
	if not can_add_weapon(weapon_scene):
		return null
	var weapon: Weapon = weapon_scene.instantiate() as Weapon
	weapons_container.add_child(weapon)
	# Deferred fire for AUTOMATIC weapons so they activate immediately
	if weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
		weapon.call_deferred("try_fire")
	weapons_changed.emit()
	return weapon


# --- Artefact equipment ---

func add_artefact(artefact_id: String) -> bool:
	if artefact_id.is_empty() or has_artefact(artefact_id):
		return false
	if artefact_ids.size() >= MAX_ARTEFACT_SLOTS:
		return false
	artefact_ids.append(artefact_id)
	artefacts_changed.emit()
	return true


func has_artefact(artefact_id: String) -> bool:
	return artefact_id in artefact_ids


func get_artefact_count() -> int:
	return artefact_ids.size()


func get_artefact_slot_capacity() -> int:
	return MAX_ARTEFACT_SLOTS


func get_artefact_slot_color(slot_index: int) -> Color:
	if slot_index < 0 or slot_index >= artefact_ids.size():
		return Color(0.25, 0.25, 0.25)
	return ARTEFACTS.get_display_color(artefact_ids[slot_index])


func get_artefact_slot_name(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= artefact_ids.size():
		return ""
	return ARTEFACTS.get_display_name(artefact_ids[slot_index])


# --- Gold & Greed ---

func get_gold() -> int:
	return gold


func get_gold_multiplier() -> float:
	var mult: float = 1.0 + maxf(0.0, greed_percent_bonus)
	# Golden Touch artefact.
	if has_artefact("golden_touch"):
		mult += 0.5
	return mult


func add_gold(raw_amount: int) -> void:
	if raw_amount <= 0:
		return
	var amount := int(round(float(raw_amount) * get_gold_multiplier()))
	gold += amount
	gold_changed.emit(gold)
	# Enlightened Greed artefact: gold gained also grants XP.
	if has_artefact("greed_to_xp"):
		var mgr: Node = get_tree().get_first_node_in_group("team_xp_manager")
		if mgr and mgr.has_method("add_xp"):
			mgr.add_xp(max(1, int(round(float(amount) * 0.25))))


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(cost: int) -> bool:
	if cost <= 0:
		return true
	if gold < cost:
		return false
	gold -= cost
	gold_changed.emit(gold)
	return true

func apply_upgrade(upgrade_id: String, rarity: int = 0) -> void:
	var value: float = LevelUpMenu.get_effective_value(upgrade_id, rarity)

	match upgrade_id:
		"might_flat":
			might_flat_bonus += value
		"might_percent":
			might_percent_bonus += value
		"attack_speed":
			attack_speed_bonus += value
		"crit_chance":
			critical_hit_chance = clamp(critical_hit_chance + value, 0.0, 1.0)
		"crit_damage":
			critical_hit_damage_multiplier += value
		"area":
			area_bonus += value
		"max_health":
			var hp_val: int = int(round(value))
			max_health_bonus += hp_val
			current_health = min(current_max_health(), current_health + hp_val)
		"move_speed_percent":
			move_speed_percent_bonus += value
		"magnet":
			magnet_enabled = true
			magnet_range += value
			_apply_magnet_settings()
		"armor":
			armor += value
		"evasion":
			evasion_chance = clamp(evasion_chance + value, 0.0, 0.75)
		"lifesteal":
			lifesteal_flat += value
		"thorns":
			thorns_flat += value
		"hp_regen":
			hp_regen_per_second += value
		"revive":
			var rev_val: int = int(round(value))
			revive_count += rev_val
			revive_remaining += rev_val
		"invincibility_frames":
			invincibility_duration += value
		"growth":
			growth_percent_bonus += value
		"greed":
			greed_percent_bonus += value
		"luck":
			luck += value
		"difficulty":
			difficulty += value
		_:
			pass

	if hp_bar:
		hp_bar.max_value = current_max_health()
		if hp_bar.value > hp_bar.max_value:
			hp_bar.value = hp_bar.max_value
	_update_hp_value_label()

func set_magnet_enabled(enabled: bool) -> void:
	magnet_enabled = enabled
	_apply_magnet_settings()

func set_magnet_range(new_range: float) -> void:
	magnet_range = maxf(0.0, new_range)
	_apply_magnet_settings()

func _apply_magnet_settings() -> void:
	if magnet_shape and magnet_shape.shape is CircleShape2D:
		(magnet_shape.shape as CircleShape2D).radius = magnet_range

	if magnet_shape:
		magnet_shape.disabled = not magnet_enabled

	if magnet_area:
		magnet_area.monitoring = magnet_enabled

func _on_magnet_area_entered(area: Area2D) -> void:
	if not magnet_enabled:
		return

	if area is XPOrb and not area.is_being_collected:
		area.start_attraction(self)
	elif area is GoldPickup and not area.is_being_collected:
		area.start_attraction(self)

func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_aiming()
	handle_weapon_inputs()
	_process_regen(_delta)
	_process_lifesteal_cooldown(_delta)

# --- Movement & Aiming ---
func handle_movement() -> void:
	current_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = current_move_input * current_move_speed()
	move_and_slide()

func current_max_health() -> int:
	return max(1, max_health + max_health_bonus)

func current_move_speed() -> float:
	return maxf(0.0, speed) * maxf(0.0, 1.0 + move_speed_percent_bonus)

func _process_lifesteal_cooldown(delta: float) -> void:
	if _lifesteal_cooldown_remaining > 0.0:
		_lifesteal_cooldown_remaining = maxf(0.0, _lifesteal_cooldown_remaining - delta)

func _process_regen(delta: float) -> void:
	if hp_regen_per_second <= 0.0 or current_health <= 0:
		return

	hp_regen_bank += hp_regen_per_second * delta
	if hp_regen_bank < 1.0:
		return

	var regen_amount = int(floor(hp_regen_bank))
	hp_regen_bank -= regen_amount
	current_health = min(current_max_health(), current_health + regen_amount)
	if hp_bar:
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()

func handle_aiming() -> void:
	# Flip sprite based on mouse position relative to player (no rotation)
	sprite.flip_h = get_global_mouse_position().x < global_position.x

# --- Weapon Delegation ---
func handle_weapon_inputs() -> void:
	if weapons_container == null:
		return

	# 1. Primary Action (Left Click) — Guns, Bows, Staffs, Main Melee
	if Input.is_action_pressed("primary_attack"):
		for weapon in weapons_container.get_children():
			if weapon.has_method("try_fire") and weapon.trigger_type == Weapon.TriggerType.PRIMARY:
				weapon.try_fire()

	# 2. Secondary Action (Right Click) — Sword Slashes, Traps, Shields, Utility
	if Input.is_action_just_pressed("secondary_attack"):
		for weapon in weapons_container.get_children():
			if weapon.has_method("try_fire") and weapon.trigger_type == Weapon.TriggerType.SECONDARY:
				weapon.try_fire()

	# 3. Automatic Weapons — Books, Auras, Orbiters (Fires on internal timers)
	for weapon in weapons_container.get_children():
		if weapon.has_method("try_fire") and weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
			weapon.try_fire()

# --- Health & Damage System ---
func take_damage(amount: int) -> void:
	if is_invincible:
		return

	if randf() < clamp(evasion_chance, 0.0, 1.0):
		trigger_evasion()
		return

	# Flat armor uses the same diminishing-returns formula as attack speed:
	# 100/(100+armor). armor=100 -> 50% damage taken, armor=300 -> 25%.
	var mitigated_damage = maxf(0.0, float(amount) * get_damage_reduction_multiplier())
		
	current_health = max(0, current_health - int(round(mitigated_damage)))
	if hp_bar:
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()
	print("Player took damage! Current HP: ", current_health)
	
	if current_health <= 0:
		die()
	else:
		trigger_invincibility()

func trigger_invincibility() -> void:
	_start_invincibility_effect(invincibility_duration + invincibility_frame_bonus, Color(1, 0.3, 0.3, 0.7))

func trigger_evasion() -> void:
	_start_invincibility_effect(invincibility_duration + invincibility_frame_bonus, Color(0.35, 0.85, 1.0, 0.75))

func _start_invincibility_effect(duration: float, flash_color: Color) -> void:
	is_invincible = true
	modulate = flash_color
	
	await get_tree().create_timer(maxf(0.01, duration)).timeout
	
	modulate = Color(1, 1, 1, 1)
	is_invincible = false

func die() -> void:
	if revive_remaining > 0:
		revive_remaining -= 1
		current_health = max(1, int(round(current_max_health() * maxf(0.01, revive_health_percent))))
		if hp_bar:
			hp_bar.value = current_health
		health_changed.emit(current_health, current_max_health())
		_update_hp_value_label()
		trigger_invincibility()
		return

	print("Player Died! Reloading scene...")
	call_deferred("_reload_current_scene_safe")

func _reload_current_scene_safe() -> void:
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.reload_current_scene()

func _ensure_hp_value_label() -> void:
	if hp_bar == null or hp_value_label != null:
		return

	hp_value_label = hp_bar.get_node_or_null("ValueLabel") as Label
	if hp_value_label == null:
		hp_value_label = Label.new()
		hp_value_label.name = "ValueLabel"
		hp_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_value_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		hp_value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		hp_value_label.add_theme_constant_override("shadow_offset_x", 1)
		hp_value_label.add_theme_constant_override("shadow_offset_y", 1)
		hp_value_label.add_theme_font_size_override("font_size", 8)
		hp_bar.add_child(hp_value_label)

func _update_hp_value_label() -> void:
	if hp_value_label:
		hp_value_label.text = str(current_health) + " / " + str(current_max_health())
