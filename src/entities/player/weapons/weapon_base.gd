class_name Weapon
extends Node2D

const ExplosionEffectScript: Script = preload("res://src/effects/explosion_effect/explosion_effect.gd")

signal cooldown_started(duration: float)
signal cooldown_ended()

enum TriggerType {
	PRIMARY,   # Left Click
	SECONDARY, # Right Click / Space
	AUTOMATIC  # Fires on cooldown continuously
}

@export var weapon_name: String = "Base Weapon"
@export var trigger_type: TriggerType = TriggerType.AUTOMATIC
@export var cooldown: float = 1.0
@export var icon_texture: Texture2D
## Elemental type of the damage this weapon deals. Defaults to PHYSICAL; elemental
## weapons (fire aura, lightning, frost nova, arcane bolts) override this in _ready().
## A future ailment system will key status effects off this type.
@export var damage_type: DamageType.Type = DamageType.Type.PHYSICAL

var cooldown_timer: Timer
var can_fire: bool = true
var base_cooldown: float = 1.0

# Per-weapon stat bonuses granted by the Anvil. These are independent of the
# player's global stats, so each weapon scales on its own.
var projectile_count_bonus: int = 0
var pierce_bonus: int = 0
var chain_count_bonus: int = 0
var area_bonus: float = 0.0
var repeat_bonus: int = 0            # extra volleys fired in succession per trigger
var projectile_speed_bonus: float = 0.0  # fractional (+0.5 = +50% speed)
var close_range_damage_bonus: float = 0.0  # dmg mult in the closest third of reach
var far_range_damage_bonus: float = 0.0    # dmg mult beyond two-thirds of reach
var explosion_on_kill_chance: float = 0.0  # chance a kill triggers an AOE
var explosion_radius: float = 95.0
var explosion_damage_ratio: float = 0.6    # as a fraction of the killing hit

# On-hit status effects (share a common duration).
var on_hit_burn_pct: float = 0.0   # burn DPS as fraction of the hit's damage
var on_hit_bleed_dps: float = 0.0  # flat bleed DPS per stack
var on_hit_poison_pct: float = 0.0 # poison DPS as fraction of enemy max HP
var status_duration: float = 3.0

func _ready() -> void:
	base_cooldown = cooldown
	# Check if a CooldownTimer child already exists; if not, create one safely
	cooldown_timer = get_node_or_null("CooldownTimer") as Timer
	if cooldown_timer == null:
		cooldown_timer = Timer.new()
		cooldown_timer.name = "CooldownTimer"
		add_child(cooldown_timer)
		
	cooldown_timer.wait_time = base_cooldown
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_finished)

func try_fire() -> void:
	if can_fire:
		_fire_with_repeat()
		can_fire = false
		var effective_cooldown = get_effective_cooldown()
		cooldown_timer.start(effective_cooldown)
		cooldown_started.emit(effective_cooldown)


# Fires once, then (for Repeat) fires again a few times in quick succession.
func _fire_with_repeat() -> void:
	var reps: int = get_fire_repeat_count()
	fire()
	for i in range(1, reps):
		await get_tree().create_timer(0.08 * float(i)).timeout
		if not is_instance_valid(self):
			return
		fire()

# Virtual function — overridden by specific weapons
func fire() -> void:
	pass

func get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func get_effective_cooldown() -> float:
	var player = get_player()
	if player == null:
		return maxf(0.05, base_cooldown)

	# Mana Overload (mage secondary) can halve all cooldowns temporarily.
	var mult: float = 1.0
	if player.has_method("get_cooldown_multiplier"):
		mult = maxf(0.05, float(player.get_cooldown_multiplier()))

	return maxf(0.05, base_cooldown * player.get_attack_speed_multiplier() * mult)

# Area stat: scales the radius of AOE skills and the size of projectiles.
# Now a per-weapon stat (moved out of the level-up pool into the anvil).
func get_area_multiplier() -> float:
	return maxf(0.25, 1.0 + area_bonus)

# Effective projectile count (base + anvil bonus).
func get_effective_projectile_count(base: int) -> int:
	return maxi(1, base + projectile_count_bonus)

# Effective pierce count (base + anvil bonus).
func get_effective_pierce(base: int) -> int:
	return maxi(0, base + pierce_bonus)

# Effective chain count (base + anvil bonus).
func get_effective_chain_count(base: int) -> int:
	return maxi(0, base + chain_count_bonus)

# Effective projectile travel speed (base + anvil bonus).
func get_effective_projectile_speed(base_speed: float) -> float:
	return maxf(0.0, base_speed * (1.0 + projectile_speed_bonus))

# Returns the number of times this weapon should fire per trigger (repeat).
func get_fire_repeat_count() -> int:
	return maxi(1, repeat_bonus + 1)

# --- Anvil capability reporting -------------------------------------------
# Each weapon overrides the stats it can actually use, so the anvil only offers
# relevant upgrades. Area is available to every weapon by default.

func supports_projectile_count() -> bool:
	return false

func supports_pierce() -> bool:
	return false

func supports_chain() -> bool:
	return false

func supports_area() -> bool:
	return true

func supports_repeat() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return false

func supports_range_damage() -> bool:
	return false

func supports_explosion_on_kill() -> bool:
	return true

# Whether this weapon can apply on-hit status effects (burn/bleed/poison).
func supports_status_effects() -> bool:
	return true

func get_attack_damage(base_damage: float) -> int:
	var player = get_player()
	if player == null:
		return max(0, int(round(base_damage)))

	return player.get_attack_damage(base_damage)

func roll_critical_hit() -> bool:
	var player = get_player()
	if player == null:
		return false

	return player.roll_critical_hit()

func get_critical_multiplier() -> float:
	var player = get_player()
	if player == null:
		return 2.0

	return player.get_critical_multiplier()

func apply_lifesteal() -> void:
	var player = get_player()
	if player:
		player.apply_lifesteal()


# Multiplies damage by the close/far bonus depending on how far the hit is from
# the player. Reach = distance from the player (screen center) to the edge of
# the screen. Close = first third, far = beyond two-thirds, middle = neutral.
func get_range_damage_multiplier(distance_from_player: float) -> float:
	if close_range_damage_bonus <= 0.0 and far_range_damage_bonus <= 0.0:
		return 1.0
	var reach: float = _get_screen_reach()
	if reach <= 0.0:
		return 1.0
	if distance_from_player <= reach / 3.0:
		return 1.0 + close_range_damage_bonus
	if distance_from_player >= reach * 2.0 / 3.0:
		return 1.0 + far_range_damage_bonus
	return 1.0


func _get_screen_reach() -> float:
	var vp := get_viewport()
	if vp == null:
		return 0.0
	var size := vp.get_visible_rect().size
	return size.length() * 0.5


# Applies this weapon's on-hit status effects to an enemy that was just hit.
# Call this from the weapon / projectile right after dealing damage.
func apply_status_on_hit(target: Node, hit_damage: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_burn") and not target.has_method("apply_bleed") and not target.has_method("apply_poison"):
		return
	if on_hit_burn_pct > 0.0 and target.has_method("apply_burn"):
		target.apply_burn(float(hit_damage), status_duration, on_hit_burn_pct)
	if on_hit_bleed_dps > 0.0 and target.has_method("apply_bleed"):
		target.apply_bleed(on_hit_bleed_dps, status_duration)
	if on_hit_poison_pct > 0.0 and target.has_method("apply_poison"):
		target.apply_poison(on_hit_poison_pct, status_duration)


# After scoring a kill (enemy died), possibly trigger an explosion AOE.
func apply_explosion_on_kill(origin: Vector2, kill_damage: int) -> void:
	if explosion_on_kill_chance <= 0.0:
		return
	if randf() > explosion_on_kill_chance:
		return
	_explode_at(origin, kill_damage)


func _explode_at(origin: Vector2, kill_damage: int) -> void:
	var eff_radius: float = explosion_radius * get_area_multiplier()
	var dmg: int = maxi(1, int(round(float(kill_damage) * explosion_damage_ratio)))
	_spawn_explosion_visual(origin, eff_radius)
	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		targets.append(d)
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= eff_radius:
			en.take_damage(dmg, false, damage_type)


## Spawns a short-lived expanding-ring visual so explosions are clearly visible.
func _spawn_explosion_visual(origin: Vector2, eff_radius: float) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	# Instantiate via preload (not the registered class_name) so this base class
	# stays decoupled from the global class cache of a freshly-added effect.
	var fx: Node2D = ExplosionEffectScript.new()
	fx.name = "ExplosionFX"
	fx.global_position = origin
	fx.set("max_radius", eff_radius)
	tree.current_scene.add_child(fx)


func _on_cooldown_finished() -> void:
	can_fire = true
	cooldown_ended.emit()
