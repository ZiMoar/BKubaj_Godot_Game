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
@export var invincibility_duration: float = 0.05
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

# --- Class Mobility Ability (Space) ---
# Per-class movement tool config, keyed by ClassBase.class_ability_id.
const MOBILITY_CONFIG: Dictionary = {
	"shield_charge": {
		"type": "dash",
		"speed": 720.0,
		"duration": 0.30,
		"cooldown": 3.5,
		"invincible": true,
		"shove": 360.0,
	},
	"teleport": {
		"type": "teleport",
		"range": 260.0,
		"cooldown": 3.0,
		"invincible": true,
	},
	"dodge_roll": {
		"type": "dash",
		"speed": 520.0,
		"duration": 0.20,
		"cooldown": 1.5,
		"invincible": true,
	},
}
var _mobility_active: bool = false
var _mobility_velocity: Vector2 = Vector2.ZERO
var _mobility_time_left: float = 0.0
var _mobility_cd_remaining: float = 0.0
var _mobility_id: String = ""

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
	# The player travels through ALL enemies (both ground mobs and flying ones).
	# Contact damage is handled by the enemies' Hitbox areas, not physical
	# collision, so clear the Enemies (3) and Flying (6) layer bits from our
	# collision mask. This guarantees the player is never body-blocked regardless
	# of any individual enemy's mask.
	collision_mask &= ~(4 | 32)  # drop layer bits 3 (Enemies) and 6 (Flying)

	# Apply the chosen class's starting stat overrides BEFORE computing HP.
	_apply_class_starting_stats()
	# Continuing a run? Restore the carried-over progression (stats, weapons,
	# artefacts, gold) captured from the previous stage's player.
	var run_state: Node = get_node_or_null("/root/GameState")
	var xp_mgr: Node = null
	if run_state and run_state.run_active:
		xp_mgr = get_tree().get_first_node_in_group("team_xp_manager") as Node
		run_state.apply_continue(self, xp_mgr)
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

## The class chosen in the main menu's class-selection screen (GameState
## autoload). Returns the class node, or null if unavailable.
func _get_selected_class() -> ClassBase:
	var state: Node = get_node_or_null("/root/GameState")
	if state == null:
		return null
	if state.has_method("get_selected_class"):
		return state.get_selected_class() as ClassBase
	return null


## Applies the selected class's starting stat overrides onto this player.
func _apply_class_starting_stats() -> void:
	var cls: ClassBase = _get_selected_class()
	if cls == null:
		return
	if cls.has_method("apply_starting_stats"):
		cls.apply_starting_stats(self)


## Equips the class-defined Primary + Secondary weapons from the selected class.
func _setup_class_starting_weapons() -> void:
	if weapons_container == null:
		return
	# When continuing a run, the captured weapon list was already restored —
	# adding the class starting weapons now would duplicate them.
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.run_active and run_state.stage > 1:
		return
	var cls: ClassBase = _get_selected_class()
	if cls == null:
		return
	var scenes: Array[PackedScene] = []
	if cls.primary_weapon_scene != null:
		scenes.append(cls.primary_weapon_scene)
	if cls.secondary_ability_scene != null:
		scenes.append(cls.secondary_ability_scene)
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

func _physics_process(delta: float) -> void:
	handle_movement()
	handle_aiming()
	handle_weapon_inputs()
	_process_class_ability_input(delta)
	_process_regen(delta)
	_process_lifesteal_cooldown(delta)

# --- Movement & Aiming ---
func handle_movement() -> void:
	current_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# While a mobility trick is active, override normal movement with the dash.
	if _mobility_active:
		velocity = _mobility_velocity + current_move_input * current_move_speed() * 0.2
		move_and_slide()
		_mobility_time_left -= get_physics_process_delta_time()
		if _mobility_time_left <= 0.0:
			_mobility_active = false
			_apply_mobility_shove()
		return
	velocity = current_move_input * current_move_speed()
	move_and_slide()

func current_max_health() -> int:
	return max(1, max_health + max_health_bonus)

func current_move_speed() -> float:
	return maxf(0.0, speed) * maxf(0.0, 1.0 + move_speed_percent_bonus)

# --- Class Mobility Ability (Space) ---
func _process_class_ability_input(delta: float) -> void:
	if _mobility_cd_remaining > 0.0:
		_mobility_cd_remaining = maxf(0.0, _mobility_cd_remaining - delta)
	if Input.is_action_just_pressed("class_ability"):
		trigger_class_ability()

func _get_class_ability_id() -> String:
	var cls: ClassBase = _get_selected_class()
	if cls == null:
		return ""
	return str(cls.get("class_ability_id"))

func trigger_class_ability() -> void:
	if _mobility_active or _mobility_cd_remaining > 0.0:
		return
	var ab_id: String = _get_class_ability_id()
	_mobility_id = ab_id
	var cfg: Dictionary = MOBILITY_CONFIG.get(ab_id, {})
	if cfg.is_empty() or cfg.get("type", "") == "":
		return
	var direction: Vector2 = _mobility_direction()
	if cfg.get("type") == "teleport":
		_do_teleport(cfg, direction)
	else:
		_start_dash(cfg, direction)
	_mobility_cd_remaining = float(cfg.get("cooldown", 1.0))

# --- Public queries for the HUD ability-cooldown display ---
## Id of the current class ability (e.g. "shield_charge"), or "" if none.
func get_class_ability_id() -> String:
	if _mobility_id != "":
		return str(_mobility_id)
	return _get_class_ability_id()


## Human-readable label for the current class ability (e.g. "Shield Charge").
func get_class_ability_name() -> String:
	var names: Dictionary = {
		"shield_charge": "Shield Charge",
		"teleport": "Teleport",
		"dodge_roll": "Dodge Roll",
	}
	return str(names.get(_mobility_id, ""))


## Cooldown ready fraction: 0.0 = ready, 1.0 = just used (full CD remaining).
func get_class_ability_cooldown_ratio() -> float:
	var cfg: Dictionary = MOBILITY_CONFIG.get(_mobility_id, {})
	var total: float = float(cfg.get("cooldown", 1.0))
	if total <= 0.0:
		return 0.0
	return clampf(_mobility_cd_remaining / total, 0.0, 1.0)


func is_class_ability_ready() -> bool:
	return _mobility_cd_remaining <= 0.0 and not _mobility_active


func _mobility_direction() -> Vector2:
	# Prefer movement direction if present, else fall back to facing/aim.
	if current_move_input.length_squared() > 0.01:
		return current_move_input.normalized()
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		return to_mouse.normalized()
	return Vector2.RIGHT

func _start_dash(cfg: Dictionary, direction: Vector2) -> void:
	_mobility_active = true
	_mobility_velocity = direction * float(cfg.get("speed", 500.0))
	_mobility_time_left = float(cfg.get("duration", 0.25))
	if cfg.get("invincible", true):
		start_mobility_invincibility(float(cfg.get("duration", 0.25)) + 0.1)

func _do_teleport(cfg: Dictionary, direction: Vector2) -> void:
	var range_: float = float(cfg.get("range", 240.0))
	var target: Vector2 = global_position + direction * range_
	# Clamp to the arena's interior so the mage can't blink through walls.
	var floor_node: Node = _find_floor_node()
	if floor_node != null and floor_node.get("arena_center") != null and floor_node.get("arena_size") != null:
		var arena_center: Vector2 = floor_node.arena_center
		var arena_size: Vector2 = floor_node.arena_size
		var margin := 40.0
		var bounds: Rect2 = Rect2(arena_center - arena_size * 0.5 + Vector2(margin, margin), arena_size - Vector2(margin * 2.0, margin * 2.0))
		target.x = clampf(target.x, bounds.position.x, bounds.position.x + bounds.size.x)
		target.y = clampf(target.y, bounds.position.y, bounds.position.y + bounds.size.y)
	global_position = target
	if cfg.get("invincible", true):
		start_mobility_invincibility(0.25)
	_apply_mobility_shove()

func start_mobility_invincibility(duration: float) -> void:
	_start_invincibility_effect(duration, Color(0.6, 0.8, 1.0, 0.7))

# Room a dash/teleport packs a little punch: shove nearby enemies back.
func _apply_mobility_shove() -> void:
	if _mobility_id == "dodge_roll":
		return
	var cfg: Dictionary = MOBILITY_CONFIG.get(_mobility_id, {})
	var shove: float = float(cfg.get("shove", 0.0))
	if shove <= 0.0:
		return
	var radius := 70.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("apply_knockback"):
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.apply_knockback(global_position, shove)

func _find_floor_node() -> Node:
	var node: Node = self
	while node != null:
		var f: Node = node.get_node_or_null("Floor")
		if f != null:
			return f
		node = node.get_parent()
	return null

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
# Minimum time between hits from the SAME source. Prevents a single enemy /
# projectile from hitting the player repeatedly within a short window even
# though the global invincibility flash alone is very short (0.05s).
const SOURCE_HIT_COOLDOWN: float = 0.5
# Tracks the last time each damage source hit the player (Node -> epoch seconds).
var _source_last_hit: Dictionary = {}

func take_damage(amount: int, source: Node = null) -> void:
	if is_invincible:
		return

	# Global i-frames are intentionally short (0.05s). Most incoming damage is
	# instead throttled per-source: a single source can't hit more than once per
	# SOURCE_HIT_COOLDOWN, but different sources can still pile damage on.
	if source != null and is_instance_valid(source):
		var now: float = Time.get_ticks_msec() / 1000.0
		var last: float = _source_last_hit.get(source, -INF)
		if now - last < SOURCE_HIT_COOLDOWN:
			return
		_source_last_hit[source] = now

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
	# Ending the run means a scene reload starts a fresh run, not a continuation.
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.has_method("end_run"):
		run_state.end_run()
	call_deferred("_reload_current_scene_safe")

func _reload_current_scene_safe() -> void:
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.reload_current_scene()

# --- Run persistence (used to carry progression into the next stage) ---

## Returns a snapshot of the player's full progression so the next stage's fresh
## Player instance can be rebuilt identically.
func capture_run_state() -> Dictionary:
	var stats: Dictionary = {
		"current_health": current_health,
		"max_health_bonus": max_health_bonus,
		"max_health": max_health,
		"revive_remaining": revive_remaining,
		"might_flat_bonus": might_flat_bonus,
		"might_percent_bonus": might_percent_bonus,
		"attack_speed_bonus": attack_speed_bonus,
		"critical_hit_chance": critical_hit_chance,
		"critical_hit_damage_multiplier": critical_hit_damage_multiplier,
		"area_bonus": area_bonus,
		"projectile_speed_bonus": projectile_speed_bonus,
		"duration_bonus": duration_bonus,
		"amount_bonus": amount_bonus,
		"armor_penetration_flat_bonus": armor_penetration_flat_bonus,
		"armor_penetration_percent_bonus": armor_penetration_percent_bonus,
		"hp_regen_per_second": hp_regen_per_second,
		"armor": armor,
		"evasion_chance": evasion_chance,
		"lifesteal_flat": lifesteal_flat,
		"revive_count": revive_count,
		"revive_health_percent": revive_health_percent,
		"thorns_flat": thorns_flat,
		"shield_capacity": shield_capacity,
		"move_speed_percent_bonus": move_speed_percent_bonus,
		"magnet_enabled": magnet_enabled,
		"magnet_range": magnet_range,
		"dash_charges": dash_charges,
		"dash_cooldown": dash_cooldown,
		"invincibility_duration": invincibility_duration,
		"invincibility_frame_bonus": invincibility_frame_bonus,
		"growth_percent_bonus": growth_percent_bonus,
		"greed_percent_bonus": greed_percent_bonus,
		"luck": luck,
		"gold": gold,
		"rerolls": rerolls,
		"banish_count": banish_count,
		"difficulty": difficulty,
		"pierce_bonus": pierce_bonus,
		"artefact_ids": artefact_ids.duplicate(),
	}
	# Capture each equipped weapon by its scene path + its anvil stat bonuses.
	var weapons: Array[Dictionary] = []
	if weapons_container:
		for w: Node in weapons_container.get_children():
			if not (w is Weapon):
				continue
			var path: String = w.scene_file_path
			if path.is_empty():
				continue
			weapons.append({
				"path": path,
				"projectile_count_bonus": w.projectile_count_bonus,
				"pierce_bonus": w.pierce_bonus,
				"chain_count_bonus": w.chain_count_bonus,
				"area_bonus": w.area_bonus,
				"repeat_bonus": w.repeat_bonus,
				"projectile_speed_bonus": w.projectile_speed_bonus,
				"close_range_damage_bonus": w.close_range_damage_bonus,
				"far_range_damage_bonus": w.far_range_damage_bonus,
				"explosion_on_kill_chance": w.explosion_on_kill_chance,
				"status_duration": w.status_duration,
				"on_hit_burn_pct": w.on_hit_burn_pct,
				"on_hit_bleed_dps": w.on_hit_bleed_dps,
				"on_hit_poison_pct": w.on_hit_poison_pct,
			})
	stats["weapons"] = weapons
	return stats


## Rebuilds this (freshly-instantiated) player from a captured run snapshot.
func restore_run_state(snap: Dictionary) -> void:
	for key: String in snap.keys():
		if key in self and key != "weapons":
			set(key, snap[key])
	# Restore the equipped weapon list (this player had no weapons yet).
	if weapons_container and snap.has("weapons"):
		var weapons: Array = snap["weapons"]
		for wdata: Dictionary in weapons:
			var path: String = wdata.get("path", "")
			if path.is_empty():
				continue
			var ws: PackedScene = load(path) as PackedScene
			if ws == null:
				continue
			if not can_add_weapon(ws):
				continue
			var weapon: Weapon = ws.instantiate() as Weapon
			weapons_container.add_child(weapon)
			weapon.projectile_count_bonus = wdata.get("projectile_count_bonus", 0)
			weapon.pierce_bonus = wdata.get("pierce_bonus", 0)
			weapon.chain_count_bonus = wdata.get("chain_count_bonus", 0)
			weapon.area_bonus = wdata.get("area_bonus", 0.0)
			weapon.repeat_bonus = wdata.get("repeat_bonus", 0)
			weapon.projectile_speed_bonus = wdata.get("projectile_speed_bonus", 0.0)
			weapon.close_range_damage_bonus = wdata.get("close_range_damage_bonus", 0.0)
			weapon.far_range_damage_bonus = wdata.get("far_range_damage_bonus", 0.0)
			weapon.explosion_on_kill_chance = wdata.get("explosion_on_kill_chance", 0.0)
			weapon.status_duration = wdata.get("status_duration", 3.0)
			weapon.on_hit_burn_pct = wdata.get("on_hit_burn_pct", 0.0)
			weapon.on_hit_bleed_dps = wdata.get("on_hit_bleed_dps", 0.0)
			weapon.on_hit_poison_pct = wdata.get("on_hit_poison_pct", 0.0)
			if weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
				weapon.call_deferred("try_fire")
	weapons_changed.emit()

## Raises the player's base difficulty to at least the given floor. This is how
## each stage's minimum difficulty is enforced (enemies scale off this value).
func set_min_difficulty(player_floor: float) -> void:
	difficulty = maxf(difficulty, player_floor)

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
